#!/usr/bin/env python3
"""Exercise the standalone CLI with real CMake/compilers in temporary projects."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "bootstrap-c"


class BootstrapTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bootstrap-c-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        # This copy deliberately has no adjacent template files or dotfiles repo.
        self.cli = self.root / "installed" / "bootstrap-c"
        self.cli.parent.mkdir()
        shutil.copy2(SCRIPT, self.cli)
        # Apple's /usr/bin/python3 launcher injects CPATH=/usr/local/include.
        # Keep tests independent of ambient include paths; retain CC/CXX overrides.
        self.env = os.environ.copy()
        for key in ("CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "OBJC_INCLUDE_PATH"):
            self.env.pop(key, None)

    def run_cli(self, *args, input_text="", success=True):
        result = subprocess.run(
            [str(self.cli), *map(str, args)],
            cwd=self.root,
            env=self.env,
            input=input_text,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def run_tool(self, args, project, success=True):
        result = subprocess.run(
            args, cwd=project, env=self.env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def test_menus_build_both_languages_and_enforce_warnings(self):
        for language_choice, extension in (("1", "c"), ("2", "cpp")):
            with self.subTest(extension=extension):
                project = self.root / ("project with spaces " + extension)
                # Invalid menu input must reprompt, then select the default standard.
                result = self.run_cli(project, "--name", "demo",
                                      input_text="invalid\n" + language_choice + "\n\n")
                self.assertIn("Choose a number", result.stdout)
                self.assertIn("both presets built", result.stdout)
                self.assertFalse((project / "builds").exists())
                self.assertEqual(
                    {entry.name for entry in (project / "build").iterdir()},
                    {"debug", "release"},
                )
                for build in ("build/debug", "build/release"):
                    database = json.loads((project / build / "compile_commands.json").read_text())
                    self.assertEqual(len(database), 1)
                    self.assertTrue(database[0]["file"].endswith("main." + extension))
                    self.assertIn("-Werror", database[0]["command"])
                    self.assertIn("-std=", database[0]["command"])
                    self.run_tool([str(project / build / "demo")], project)
                self.assertIn("CompilationDatabase: build/debug", (project / ".clangd").read_text())
                self.assertEqual((project / ".gitignore").read_bytes(), (project / ".ignore").read_bytes())
                self.assertFalse((project / ".clang-format").is_symlink())
                if shutil.which("clang-format"):
                    self.run_tool(["make", "check"], project)
                # A real warning must fail both configurations, not merely appear in a file.
                (project / "src" / ("main." + extension)).write_text(
                    "int main(void) {\n  int unused;\n  return 0;\n}\n"
                )
                for preset in ("debug", "release"):
                    # Make can miss edits within one timestamp tick on fast filesystems.
                    failure = self.run_tool(
                        ["cmake", "--build", "--preset", preset, "--clean-first"], project, False
                    )
                    self.assertIn("unused", failure.stdout)
                    self.assertIn("error:", failure.stdout)

    def test_all_standard_menu_choices(self):
        for language, cmake_language, standards in (
            ("1", "C", [23, 17, 11, 99, 90]),
            ("2", "CXX", [23, 20, 17, 14, 11, 98, 26]),
        ):
            for choice, standard in enumerate(standards, 1):
                with self.subTest(language=cmake_language, standard=standard):
                    project = self.root / (cmake_language + str(standard))
                    self.run_cli("--no-configure", project, input_text=f"{language}\n{choice}\n")
                    cmake = (project / "CMakeLists.txt").read_text()
                    self.assertIn(f"{cmake_language}_STANDARD {standard}\n", cmake)
                    self.assertIn(f"{cmake_language}_STANDARD_REQUIRED YES", cmake)
                    self.assertFalse((project / "builds").exists())
                    self.assertFalse((project / "build").exists())

    def test_manual_template_and_cli_share_the_layout(self):
        project = self.root / "manual-template"
        shutil.copytree(SCRIPT.parents[1] / "templates" / "cpp", project)
        generated = self.root / "generated"
        self.run_cli("--no-configure", "--language", "c++", "--standard", "23", generated)
        for root in (project, generated):
            presets = json.loads((root / "CMakePresets.json").read_text())
            base, debug, release = presets["configurePresets"]
            self.assertEqual(base["binaryDir"], "${sourceDir}/build/${presetName}")
            self.assertNotIn("binaryDir", debug)
            self.assertNotIn("binaryDir", release)
            self.assertIn("CompilationDatabase: build/debug", (root / ".clangd").read_text())
        for preset in ("debug", "release"):
            self.run_tool(["make", "run", "PRESET=" + preset], project)
            database = json.loads((project / "build" / preset / "compile_commands.json").read_text())
            self.assertTrue(database)
            self.assertEqual(Path(database[0]["directory"]).resolve(), (project / "build" / preset).resolve())
        self.assertFalse((project / "builds").exists())

    def test_existing_files_and_symlinks_are_untouched(self):
        for filename in ("README.md", ".clangd", "src", "dangling"):
            with self.subTest(filename=filename):
                project = self.root / filename.strip(".")
                project.mkdir()
                existing = project / filename
                if filename == "dangling":
                    existing.symlink_to("missing")
                else:
                    existing.write_text("keep me\n")
                self.run_cli("--language", "c", "--standard", "23", project, success=False)
                self.assertEqual(list(project.iterdir()), [existing])
                if existing.is_symlink():
                    self.assertEqual(os.readlink(existing), "missing")
                else:
                    self.assertEqual(existing.read_text(), "keep me\n")

    def test_existing_git_and_noninteractive_flags(self):
        project = self.root / "existing-git"
        (project / ".git").mkdir(parents=True)
        (project / ".git" / "sentinel").write_text("preserve\n")
        self.run_cli("--language", "c++", "--standard", "20", "--no-configure", project)
        self.assertEqual((project / ".git" / "sentinel").read_text(), "preserve\n")
        self.assertIn("CXX_STANDARD 20", (project / "CMakeLists.txt").read_text())

    def test_invalid_arguments_and_eof_do_not_create_projects(self):
        for args in (
            ["--language", "rust"],
            ["--language", "c", "--standard", "26"],
            ["--language", "c++", "--standard", "23", "--name", "bad;name"],
            ["--language", "c++", "--standard", "23", "--name", "all"],
            ["--unknown"],
            [],
        ):
            with self.subTest(args=args):
                project = self.root / "not-created"
                self.run_cli(*args, project, success=False)
                self.assertFalse(project.exists())
        self.run_cli("--standard", success=False)
        self.run_cli("--help")
        self.run_cli("--version")


if __name__ == "__main__":
    unittest.main(verbosity=2)
