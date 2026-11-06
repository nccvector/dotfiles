# Dotfiles

Personal home configuration, a temporary Nix tools shell, and reusable project templates.
Run `install.sh` to enter the tools shell; individual home files are never installed by it.

| Directory | Purpose |
| --- | --- |
| `home/` | Mirrors `$HOME`: `.config/`, `.zshrc`, `.ideavimrc`, `.intellimacs/`, `.claude/`, `.clang-format`, `.clang-tidy`, clangd user config |
| `scripts/bootstrap-c` | Standalone interactive C/C++ project bootstrap; install anywhere on PATH |
| `templates/cpp/` | Standalone C++23 demo with CMake presets, Makefile, formatting, and clangd |
| `archive/` | Alternative Helix config and the old Vim setup; not installation defaults |

## One-step tools shell

On **Apple Silicon macOS** or **x86_64/aarch64 Linux**, open `install.sh` on GitHub,
copy the **whole file**, paste it into a terminal, and press Enter. You do not need
Git for this path: it downloads a temporary repository snapshot. The computer
needs internet access, a normal Unix terminal, and curl or wget (macOS has curl).
Use Linux through WSL2 on Windows. Automatic Nix bootstrapping on Intel macOS is
not currently supported by the pinned installer; an existing Nix installation
can still be used there, subject to package availability.

Alternatively, with Git already installed:

```sh
git clone https://github.com/nccvector/dotfiles.git
cd dotfiles
sh ./install.sh
```

`install.sh` is the **only root `.sh` install script**. Both methods automatically
install Nix if it is missing, obtain the pinned tools, and open a configured Zsh
shell. Run the same script every time you want to enter again. A checkout keeps
your local config edits; pasted installs use a fresh snapshot of `main`. The
online instructions work after this change is merged. During PR review, use the
clone path and check out the PR branch.

**First-time Nix installation makes system changes.** The pinned
[NixOS community installer](https://github.com/NixOS/nix-installer/tree/2.35.4)
shows its plan and asks for confirmation and, if needed, your administrator
password. Expect `/nix`, dedicated build users, a daemon, Nix configuration, and
on macOS an APFS volume/mount setup. This cannot happen inside a Nix shell:
Nix must exist before it can provide one. No command bypasses these prompts or
uses `--force`. If you decline, installation stops. Existing shell profiles are
preserved using this installer's `--no-modify-profile`; the wrapper finds Nix by
its explicit path on later runs. Existing Nix installations are reused without
updating their configuration, channels, or globally installed packages.

### What is in the shell?

`rg`, `btop`, `hx`, `lazygit`, `yazi`, and `zoxide` are available, plus Git, fzf,
file/preview/archive helpers, LLVM tools, CMake/Make, Python LSP/format/debug tools,
and Rust compiler/LSP/format/lint tools required by the included editor config.
The first download can be several gigabytes. `shell.nix` fixes one Nixpkgs
revision, so entering a shell does not silently upgrade your tools. Helix uses
the Nix package's bundled runtime and grammars.

The shell copies the repository's Helix, Lazygit, and Yazi configs into a private
temporary directory. Only those copies receive portability fixes: clangd comes
from PATH, rustfmt uses the packaged stable tool, and Yazi uses its current
`[mgr]` setting. The prompt, cursor shape, and fzf integration are adapted from
`.zshrc`; its machine-specific paths, external hooks, and `cd ~` are omitted.
The original `.zshrc` is not sourced. Desktop/terminal/IDE configs, Claude hooks,
and old Neovim/Emacs setups remain reference files; this shell does not install
or launch those applications. Existing global Git credentials/settings remain
available via your real HOME. The global home clang-format/clang-tidy/clangd
files are not installed; project-specific configuration continues to work.

### Everyday use, multiple shells, and leaving

The `[dotfiles]` prompt identifies this shell. It starts in the same directory
you ran the script from. Try:

```sh
rg --version
hx README.md
lazygit
yazi
btop
cd /path/to/a/project
z /path/to/a/project    # learns and visits it
cd /tmp
z project              # fuzzy jump after that directory has been learned
exit                   # or Ctrl-D; returns to your previous shell
```

You can open as many shells as you like in separate terminal tabs. Each has its
own temporary configs, history, caches, and zoxide database; packages in `/nix`
are shared. A nested invocation also works, but separate tabs are easier to
understand. Every shell exit discards its config changes, history and learned
`z` destinations. To keep a config change, edit its source in your checkout and
start a new shell. Ctrl-C interrupts the current command; it does not normally
leave the interactive shell. Closing normally cleans temporary files. A forced
kill or power loss can leave a `dotfiles-session.*` or `dotfiles-bootstrap.*`
directory under your system temporary directory; remove it only after its shell
has ended.

**This is a tools environment, not a filesystem or security sandbox.** Your real
HOME and project files remain accessible. Intentional edits, Git commits,
programs you launch, and commands you run can persist changes. Tool selection
and config environment variables apply only to the shell and its children;
your parent shell and existing home configs are not rewritten by this wrapper.
GUI applications launched elsewhere do not inherit the tools shell.

Nix keeps downloaded sources and packages in its persistent store/cache for
reuse. Leaving does not uninstall Nix or erase that cache. Avoid garbage
collection during active shells. If you later want to reclaim unused packages,
read [Nix garbage collection](https://nix.dev/manual/nix/stable/command-ref/nix-collect-garbage)
first: it can affect other Nix environments and future sessions may download
again. Full Nix removal is a separate, deliberate operation using the
community installer's `/nix/nix-installer uninstall` plan; exiting a shell does
not perform it. Neither cleanup nor uninstall is run automatically.

### Review and manual testing

For a command without staying in the interactive shell:

```sh
sh ./install.sh --command 'rg --version; hx --version; type z'
```

1. Before starting, note `command -v hx`, your PATH, and checksums of any existing
   `~/.zshrc`, Helix, Lazygit, and Yazi config files. Run the installer in a clone
   whose path contains spaces, from a project directory outside the repo.
2. On a fresh supported machine, review and accept the Nix installation plan
   yourself. Verify existing shell profiles are preserved. On a machine with
   Nix already installed, confirm no installer is invoked.
3. Run `python3 "$DOTFILES_ROOT/tests/check-nix-tools"` inside the shell. It checks
   real Nix binary paths, starts/exits Helix and Yazi in terminals with the copied
   configs, and checks Lazygit's config directory. Open `lazygit` in a Git repo
   and `btop` manually too. In Helix, `:health cpp` should find the Nix clangd.
4. Try the `z` example above. Open another tools shell and confirm it works
   independently. In one shell, run `sleep 30`, press Ctrl-C, then type `exit`.
   Your other shell should still work. Exit it with Ctrl-D.
5. Check the recorded host PATH, tool selection, and home config checksums are
   unchanged. Confirm temporary config directories are gone, while deliberate
   project edits and the Nix cache remain.
6. For the online path during PR review, export `DOTFILES_REF=ali/portable-nix-shell`
   in a terminal, then paste the whole reviewed `install.sh` file. After merging,
   unset `DOTFILES_REF` and repeat to test `main` without cloning or Git.

`python3 tests/test-nix-shell.py` exercises launcher and lifecycle behavior with
**mocked Nix** and real host Zsh/zoxide/fzf. It does not prove package evaluation,
builds, or fresh-machine Nix installation. The GitHub Actions workflow separately
builds the real Nix shell and smoke-tests both entry paths on a disposable Linux
runner. Check the PR's current CI result; a queued or failed run is not a pass.
macOS administrator-authenticated installation remains a manual check when the
agent cannot obtain your password. No automated test is a claim of fresh-machine
macOS verification.

For background, [Nix development environments](https://nix.dev/tutorials/first-steps/declarative-shell.html)
explains how declared packages become available together without replacing the
operating system's tools. Keep project dependencies in each project's own Nix
file when appropriate; this repository supplies your general-purpose tools.

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
presets so the compilation databases exist immediately. All generated build
files live under one `build/` directory: `build/debug/` and `build/release/`.
Both presets inherit `binaryDir: "${sourceDir}/build/${presetName}"` from the base
preset; clangd reads `build/debug/compile_commands.json`.
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
policy adjustment. clang-tidy enables all checks except `llvmlibc-*` and treats
its warnings as errors in `make lint`. LLVM libc implementation rules do not
apply to applications using system headers. Some style checks compete, so this
separate review command can reject even the starter; it is not part of `make check`.
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
`home/` or `templates/cpp/` configs. The manual C++ template uses the same build
layout as the CLI.

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
| `debug` | `build/debug/` | `build/debug/compile_commands.json` |
| `release` | `build/release/` | `build/release/compile_commands.json` |

Both presets share the `build/` root and inherit
`binaryDir: "${sourceDir}/build/${presetName}"` and
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

- `home/.clang-format` combines an LLVM-based style with
  `QualifierAlignment: Left`. It preserves the 100-column limit, block-indented
  wrapped arguments, two-space braced initializers, and short single-line ifs.
  It does not depend on `InheritParentConfig`. The template links to this one
  canonical copy. Validated with clang-format 21.1.3.
- Clang builds and clangd use `-Weverything`, not just `-Wall`. GCC has no
  equivalent universal switch; its template fallback enables `-Wall -Wextra
  -Wpedantic -Wconversion -Wshadow`.
- `home/.clang-tidy` and clangd enable `*` except `llvmlibc-*`,
  including const-correctness, unused code, nodiscard, bugprone, performance,
  readability, analyzer, portability, and modernization checks. Pointer const
  diagnostics are explicitly enabled too. LLVM libc implementation checks are
  excluded because ordinary applications should be allowed to use system headers.
- The broad diagnostic policy still includes C++98 compatibility warnings and
  mutually competing or other library-specific style advice. Review suggestions
  individually; no automatic fixes are run.
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
