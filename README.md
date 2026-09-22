# Dotfiles

Personal home configuration and small, reusable project templates. Nothing is
installed automatically.

| Directory | Purpose |
| --- | --- |
| `home/` | Mirrors `$HOME`: `.config/`, `.zshrc`, `.ideavimrc`, `.intellimacs/`, `.claude/`, `.clang-format`, `.clang-tidy`, clangd user config |
| `scripts/bootstrap-c` | Standalone interactive C/C++ project bootstrap; install anywhere on PATH |
| `templates/cpp/` | Standalone C++23 demo with CMake presets, Makefile, formatting, and clangd |
| `archive/` | Alternative Helix config and the old Vim setup; not installation defaults |

## Home configuration

Review and copy individual files from `home/` to the corresponding location in
your home directory. Back up any existing destination first. Do not copy the
entire tree blindly: it includes Linux desktop configs as well as macOS tooling.

Helix retains the GitHub keybindings and UI customization, with all-severity
inline diagnostics and an explicit Homebrew clangd server for C/C++. It has not
been replaced wholesale with the different live `~/.config/helix` files. Ghostty now lives
at the standard `home/.config/ghostty/` location. The former root `helix/` variant
is kept in `archive/helix-alternative/`.

### External dependencies

- `.ideavimrc` sources `~/helix.vim/helix.idea.vim`. Install
  [chtenb/helix.vim](https://github.com/chtenb/helix.vim) there separately. The old
  repository contained only an orphan gitlink with no `.gitmodules` or contents;
  it was removed. Its recorded revision was
  `23daee83e7b59fed41e80c31190afbb468992583`.
- `.zshrc` contains machine-specific paths, including `~/helix-fork/runtime` and
  a Zig installation. Review them before installing on another machine.
- `.claude/settings.json` references `~/claude-notification-hooks/`; those scripts
  are external and are not included here.
- Intellimacs is retained with its upstream documentation and license.

## Bootstrap a C or C++ project

Run the standalone CLI from any working directory:

```sh
/path/to/dotfiles/scripts/bootstrap-c my-project
```

Choose **C or C++**, then a language standard from numbered menus (defaults:
C++, then C++23; C defaults to C23). It supports C90/99/11/17/23 and
C++98/11/14/17/20/23/26. Compiler support is checked by configuring/building;
selecting a standard does not promise every feature is implemented by a compiler.

The destination defaults to the current directory and must be empty, except for
an optional `.git` entry. Existing files are never overwritten. Directory names
are sanitized into executable names; use `--name` to choose one explicitly.

```sh
bootstrap-c --language c --standard 23 my-project
bootstrap-c --language c++ --standard 20 --name demo "project with spaces"
bootstrap-c --no-configure my-project  # scaffold only; asks the same questions
bootstrap-c --help
```

The script writes CMakeLists, Debug/Release presets, a Makefile, a minimal main,
`include/`, `.clangd`, `.clang-format`, `.clang-tidy`, matching `.gitignore` and
`.ignore`, and a short project README. It then configures and builds **both**
presets so the compilation databases exist immediately. Debug stays at
`builds/debug/`, Release at `build/release/`; clangd reads the Debug database.
The language standard is required, extensions are disabled, and compilation
database export is forced ON even without presets. With `--no-configure`, run
`make debug` later before relying on clangd's project flags.

Requires Bash 3.2+, CMake 3.21+ (3.25+ for C++26), Make, and Clang or GCC.
Defaults to `clang`/`clang++`; set `CC`/`CXX` to another compiler executable on the
bootstrap invocation. On macOS the generated CMakeLists selects the active macOS
SDK explicitly unless SDKROOT/CMAKE_OSX_SYSROOT is supplied, avoiding accidental
host include paths under strict warnings. It does not install dependencies or
initialize Git.
Install clangd, clang-format and clang-tidy separately for editor/quality tools.
The embedded format style matches `home/.clang-format` and was tested with
clang-format 23. Tool overrides work with Make, for example:

```sh
make run
make release
make check                 # build + formatting check
make format                # format src/ and include/
make lint CLANG_TIDY=/opt/homebrew/opt/llvm/bin/clang-tidy
```

Unlike the older manual template below, generated projects enable **warnings as
errors**: Clang gets `-Weverything -Werror`; GCC gets
`-Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror`. This includes Clang's
old-standard compatibility diagnostics: modern C++ syntax can need a deliberate
policy adjustment. clang-tidy keeps all checks enabled and treats its warnings
as errors in `make lint`. Some style checks compete, so this separate review
command can reject even the starter; it is not part of `make check`.
clangd runs the same check set, though it may still display tidy advice as warnings.

### Install globally later

The script embeds its templates and uses no runtime files from this checkout.
To install it for your user (once `~/.local/bin` is on PATH):

```sh
mkdir -p ~/.local/bin
install -m 755 scripts/bootstrap-c ~/.local/bin/bootstrap-c
```

No installation is performed by the bootstrap. Embedded formatting, lint, and
ignore defaults are snapshots: synchronize them when changing the corresponding
`home/` or `templates/cpp/` configs. The older templates remain unchanged.

Regression checks (Python 3 plus the build dependencies):

```sh
python3 tests/test-bootstrap-c.py
```

## Start a C++ project manually

Requires CMake 3.21+, Make, and a C++23 compiler. From this repository:

```sh
mkdir -p ../my-project
cp -RL templates/cpp/. ../my-project/
cd ../my-project
make run
make release
make run PRESET=release
```

Use an empty destination. `-L` copies the shared `.clang-format` symlink as a
regular, self-contained file (also applies to `.clang-tidy`). Rename `demo` in `CMakeLists.txt` and the Makefile
when naming your executable.

| Preset | Build directory | Compiler database |
| --- | --- | --- |
| `debug` | `builds/debug/` | `builds/debug/compile_commands.json` |
| `release` | `build/release/` | `build/release/compile_commands.json` |

The asymmetric paths are intentional. Both presets inherit
`CMAKE_EXPORT_COMPILE_COMMANDS=ON`; the demo CMakeLists also forces it ON for
manual configuration. The Unix Makefiles generator avoids an extra Ninja
dependency and supports compiler database export.

For an existing project, copy just `CMakePresets.json`, `.clangd`, `.clang-tidy`, and
`.clang-format` (dereference the symlinks); adapt the Makefile executable name.
Keep your existing CMakeLists. Configure debug at least once so clangd can load
its database. To analyze release flags instead, change `.clangd`'s
`CompilationDatabase` to `build/release`.

`make` configures and builds debug. `make run` always builds first.
`make clean` cleans the selected, already-configured preset without deleting its
cache. Every build runs a CMake configure pass, so dependency-heavy projects may
want a narrower wrapper. For parallel compilation, set
`CMAKE_BUILD_PARALLEL_LEVEL` to your preferred job count.

## Formatting and diagnostics choices

- `home/.clang-format` combines the live global LLVM-based style with sgame's
  `QualifierAlignment: Left`. It preserves the 100-column limit, block-indented
  wrapped arguments, two-space braced initializers, and short single-line ifs.
  It does not depend on `InheritParentConfig`. The template links to this one
  canonical copy. Validated with clang-format 21.1.3.
- Clang builds and clangd use `-Weverything`, not just `-Wall`. GCC has no
  equivalent universal switch; its template fallback enables `-Wall -Wextra
  -Wpedantic -Wconversion -Wshadow`.
- `home/.clang-tidy` and clangd enable `*`: every available clang-tidy check,
  including const-correctness, unused code, nodiscard, bugprone, performance,
  readability, analyzer, portability, and modernization checks. Pointer const
  diagnostics are explicitly enabled too. No check families are excluded.
- This literal all-checks policy includes C++98 compatibility warnings and
  mutually competing or library-specific style advice (such as LLVM libc
  namespaces). Review suggestions individually; no automatic fixes are run.
  Warnings stay warnings, so they remain visible without blocking compilation.
- `FastCheckFilter: None` enables slower checks supported by clangd. clangd does
  not support every standalone clang-tidy check; use `make lint` for the full
  standalone pass. On this Mac run
  `make lint CLANG_TIDY=/opt/homebrew/opt/llvm/bin/clang-tidy`.
- Global clangd configuration is in `home/.config/clangd/config.yaml` for Linux;
  `home/Library/Preferences/clangd/config.yaml` links to it for macOS. Copy with
  symlink dereferencing when installing individual files. Global configuration
  has no hardcoded build directory; the template `.clangd` selects Debug.
- Helix displays hints and higher severities on both current and other lines;
  C/C++ explicitly use Homebrew clangd with clang-tidy enabled. Inlay hints are
  enabled as well. The archived Helix variant also shows all severities.
- clang-format is a formatter, not a linter: it has no warning-level switch.
  Its existing layout preferences are retained. Use
  `clang-format --dry-run --Werror src/*.cpp` to check formatting without edits.
- Validated with Homebrew clangd/clang-tidy 22.1.2. An LSP test verified both
  `-Wunused-variable` and `misc-const-correctness` diagnostics; Helix's health
  check confirmed the configured Homebrew server. Runtime grammars are external
  and must already be installed for syntax highlighting.

Reference: [clangd configuration](https://clangd.llvm.org/config) and
[CMake presets](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html).

## Repository hygiene

Generated Python bytecode, Neovim's compiled Packer loader, Lazygit state, and
Claude session-cost logs are removed and ignored. Recreate the Packer loader
with `:PackerCompile` after installing the existing Neovim plugins. Runtime
downloads, build directories, compiler databases, and personal CMake presets
are ignored. Prior versions remain available in Git history.

The repository and C++ template each include matching `.gitignore` and `.ignore`
files. Git ignores generated files; `.ignore` supplies the same exclusions to
compatible search tools such as ripgrep. Both exclude `**/build*`, `**/.idea*`,
`**/.vscode`, `**/cmake-build*`, editor caches, CMake outputs, and Python caches.
The requested `build*` pattern is deliberately broad: it also matches names
such as `builder.cpp` and `build-tools`. Already tracked files are not untracked
by adding ignore rules.
