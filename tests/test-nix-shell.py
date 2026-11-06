#!/usr/bin/env python3
"""Launcher/lifecycle regressions. Nix is mocked; zsh/zoxide/fzf are real.

This does NOT verify Nix evaluation, downloads, package builds, or a fresh OS install.
Run on a machine with zsh, zoxide and fzf, or inside the real tools shell.
"""
import concurrent.futures
import hashlib
import os
from pathlib import Path
import shutil
import signal
import time
import subprocess
import tarfile
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class ShellTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "existing home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.tmp = self.root / "temporary files"
        self.tmp.mkdir()
        for name, text in {
            ".zshrc": "echo USER_RC_WAS_LOADED; exit 99\n",
            ".zshenv": "echo USER_ENV_WAS_LOADED; exit 98\n",
            ".config/helix/config.toml": 'theme = "default"\n',
            "Library/Application Support/lazygit/config.yml": "# existing\n",
        }.items():
            p = self.home / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text)
        self.before = self.snapshot()
        self.env = os.environ.copy()
        self.env.update(HOME=str(self.home), TMPDIR=str(self.tmp),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        HELIX_RUNTIME="/invalid/host/runtime", TERM="xterm-256color")
        self.write_tool("nix-shell", '''#!/bin/sh
# Mock only the package provision step; run the real lifecycle helper.
case "$*" in *--pure*--run*) ;; *) exit 90;; esac
exec bash "$DOTFILES_ROOT/nix/session"
''')

    def snapshot(self):
        return {str(p.relative_to(self.home)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.home.rglob("*") if p.is_file()}

    def write_tool(self, name, text):
        p = self.bin / name
        p.write_text(text)
        p.chmod(0o755)

    def run_cli(self, command, pasted=False, success=True):
        args = ["sh", "-s", "--", "--command", command] if pasted else [
            "sh", str(REPO / "install.sh"), "--command", command]
        result = subprocess.run(args, input=(REPO / "install.sh").read_text() if pasted else "",
                                cwd=self.root, env=self.env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        self.assertEqual(result.returncode == 0, success, result.stdout)
        self.assertNotIn("USER_RC_WAS_LOADED", result.stdout)
        self.assertNotIn("USER_ENV_WAS_LOADED", result.stdout)
        self.assertEqual(self.before, self.snapshot())
        self.assertEqual(list(self.tmp.iterdir()), [], result.stdout)
        return result.stdout

    def test_local_config_and_real_z_command(self):
        out = self.run_cli('''
set -e
[[ "$PWD" = "''' + str(self.root) + '''" ]]
[[ "$HOME" = "''' + str(self.home) + '''" ]]
[[ -z ${HELIX_RUNTIME:-} ]]
[[ "$CONFIG_DIR" = "$XDG_CONFIG_HOME/lazygit" ]]
[[ "$LG_CONFIG_FILE" = "$CONFIG_DIR/config.yml" ]]
[[ "$YAZI_CONFIG_HOME" = "$XDG_CONFIG_HOME/yazi" ]]
grep -q gruvbox_dark_hard "$XDG_CONFIG_HOME/helix/config.toml"
grep -q 'command = "clangd"' "$XDG_CONFIG_HOME/helix/languages.toml"
! grep -q '+nightly' "$XDG_CONFIG_HOME/helix/languages.toml"
grep -q '^\\[mgr\\]' "$YAZI_CONFIG_HOME/yazi.toml"
mkdir -p "$DOTFILES_SESSION/jump-target"
zoxide add "$DOTFILES_SESSION/jump-target"
z jump-target
[[ "$PWD" = "$DOTFILES_SESSION/jump-target" ]]
echo REAL_Z_PASSED
''')
        self.assertIn("REAL_Z_PASSED", out)

    def test_pasted_script_downloads_snapshot_without_git(self):
        archive = self.root / "snapshot.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            for name in ["install.sh", "shell.nix", "nix", "home/.config/helix",
                         "home/.config/yazi", "home/.config/lazygit"]:
                tar.add(REPO / name, arcname="dotfiles-review/" + name)
        self.write_tool("curl", '#!/bin/sh\ncp "' + str(archive) + '" "$7"\n')
        # curl's production arguments: --fail --silent --show-error --location URL -o FILE
        self.write_tool("git", "#!/bin/sh\nexit 91\n")
        self.assertIn("PASTED_PASSED", self.run_cli("echo PASTED_PASSED", pasted=True))

    def test_nonzero_command_propagates_and_cleans(self):
        self.run_cli("exit 37", success=False)

    def test_concurrent_sessions_have_distinct_directories(self):
        def run_one(_):
            return subprocess.run(["sh", str(REPO / "install.sh"), "--command",
                                   'echo SESSION=$DOTFILES_SESSION; sleep 0.2'],
                                  cwd=self.root, env=self.env, text=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(run_one, range(2)))
        paths = []
        for result in results:
            self.assertEqual(result.returncode, 0, result.stdout)
            paths.append(next(line for line in result.stdout.splitlines() if line.startswith("SESSION=")))
        self.assertNotEqual(*paths)
        self.assertEqual(self.before, self.snapshot())
        self.assertEqual(list(self.tmp.iterdir()), [])

    def test_interactive_ctrl_c_then_exit(self):
        import fcntl
        import pty
        import select
        import struct
        import termios
        pid, fd = pty.fork()
        if pid == 0:
            os.chdir(self.root)
            os.execve("/bin/sh", ["sh", str(REPO / "install.sh")], self.env)
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 140, 0, 0))
        output = bytearray()
        reaped = False

        def read_until(token):
            end = time.monotonic() + 10
            while time.monotonic() < end:
                if select.select([fd], [], [], 0.1)[0]:
                    try:
                        output.extend(os.read(fd, 65536))
                    except OSError:
                        break
                if token in output:
                    return
            self.fail(bytes(output).decode(errors="replace"))

        try:
            read_until(b"[dotfiles]")
            time.sleep(0.5)
            os.write(fd, b"sleep 30\n")
            time.sleep(0.5)
            os.write(fd, b"\x03")
            time.sleep(0.3)
            os.write(fd, b"echo CTRL_C_PASSED\n")
            read_until(b"\x1b[2 qCTRL_C_PASSED\r\n")
            time.sleep(0.3)
            os.write(fd, b"exit\n")
            end = time.monotonic() + 10
            while time.monotonic() < end:
                if select.select([fd], [], [], 0.1)[0]:
                    try:
                        output.extend(os.read(fd, 65536))
                    except OSError:
                        pass
                got, status = os.waitpid(pid, os.WNOHANG)
                if got:
                    reaped = True
                    self.assertEqual(os.waitstatus_to_exitcode(status), 0)
                    break
            self.assertTrue(reaped, bytes(output).decode(errors="replace"))
            self.assertEqual(self.before, self.snapshot())
            self.assertEqual(list(self.tmp.iterdir()), [])
        finally:
            if not reaped:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
            os.close(fd)

    def test_exactly_one_root_install_script(self):
        self.assertEqual([p.name for p in REPO.glob("*.sh")], ["install.sh"])

    def test_invalid_argument_does_not_launch(self):
        result = subprocess.run(["sh", str(REPO / "install.sh"), "--wat"],
                                env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Usage", result.stderr)
        self.assertEqual(list(self.tmp.iterdir()), [])


if __name__ == "__main__":
    missing = [tool for tool in ("zsh", "zoxide", "fzf") if not shutil.which(tool)]
    if missing:
        raise SystemExit("Required for real shell tests: " + ", ".join(missing))
    unittest.main()
