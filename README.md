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

Open `install.sh` on GitHub, copy the **whole file**, paste it into your Unix
terminal, and press Enter. This path downloads a temporary snapshot and does
not require Git. Or, with Git installed:

```sh
git clone https://github.com/nccvector/dotfiles.git
cd dotfiles
sh ./install.sh
```

Run this same script every time you want your tools. It opens a Zsh shell in
your current directory; type `exit` or Ctrl-D to return. The `[dotfiles]` prompt
identifies it. Before this PR is merged, use the PR branch in your clone, or
export `DOTFILES_REF=ali/portable-nix-shell` before pasting the reviewed script.
Pasted installs otherwise follow `main`; local installs use your checkout.

### Platforms and prerequisites

| Platform | Bootstrap path | Verification / limits |
| --- | --- | --- |
| Ubuntu 24.04 x86_64 | Existing Nix, or rootless nix-portable + PRoot | Tested directly on fvalien; see PR evidence for exact checks |
| Other x86_64/aarch64 Linux distributions | Same rootless Linux path | Designed for these architectures; individual distros and ARM hardware have not all been tested |
| Windows WSL2 Linux distribution | Run from the Linux terminal; same Linux path | No systemd requirement in rootless mode; WSL2 not available for verification here |
| Apple Silicon macOS | Existing Nix, or community Nix installer | Shell/config lifecycle tested on the Mac; actual Nix installation/build needs administrator authentication and remains unverified |
| Intel macOS | Existing, working Nix required | Pinned community installer has no Intel macOS binary; separate compatible Nixpkgs 26.05 pin, hardware builds unverified |
| Native Windows / WSL1 / 32-bit / other CPUs | No supported bootstrap | Use a supported Linux environment; universal Linux compatibility is not claimed |

On Windows, install a WSL2 Linux distribution first and run this from its Linux
terminal, preferably with checkout/cache in the Linux home directory. The script
does not install WSL and cannot run in PowerShell or Command Prompt.

You need internet access, a writable home/cache and temporary directory, a
Unix shell, curl or wget, tar with gzip support, and `sha256sum` or `shasum`.
The Linux rootless bootstrap also needs Bash, standard utilities including
`date`, `readlink -f`, `realpath`, `base64`, `chmod`, `ln`, `find`, and `head`, an executable cache
filesystem, and permission for PRoot's process tracing. Minimal containers or
locked-down hosts may lack these prerequisites. Normal Ubuntu installations
already supply them. HTTPS downloads require a working certificate trust setup.
The rootless backend requires HOME and its cache path to contain no whitespace;
checkout/project paths may contain spaces. Expect several gigabytes of disk
space and a large first download.

The Linux path uses checksum-verified
[nix-portable v012](https://github.com/DavHau/nix-portable/tree/v012), which bundles
Nix and PRoot. It works without root, systemd, a daemon, or creating host `/nix`.
PRoot gives the shell a virtual `/nix`; it can add noticeable overhead. No host
namespace, AppArmor, ptrace-policy, or service settings are changed. If host
policy blocks it, the script fails rather than altering that policy. The same
route is intended for non-systemd distributions and WSL2. It is a tools
environment, not a security sandbox. The backend is a separate community project,
not the system Nix installer.

On Apple Silicon macOS only, missing Nix is handled by the checksum-verified
[NixOS community installer 2.35.4](https://github.com/NixOS/nix-installer/tree/2.35.4).
It shows a plan and asks for confirmation/admin authentication. This creates
system resources: `/nix`, build users, a daemon, Nix configuration, and an APFS
volume/mount setup. `--no-modify-profile` preserves existing shell startup files.
No force or unattended-confirmation option is used. You may decline and stop.
Nix must exist before it can provide a shell; installing it inside that very
shell is not possible. Existing Nix on either OS is reused without changing
its configuration, channels, or global package profiles.

### Packages and configs: what changes?

**Nix handles both the package set and the shell's config setup.** `shell.nix`
declares the tools, builds a config bundle from this repository, and generates
the session launcher. `install.sh` obtains/reuses Nix, locates the repository,
and invokes that environment. There is no second install script or helper file.

The same Nix CLI is also available inside the shell, including for nested entry.
Entry Bash is built from the pinned package set, so no host Bash version or
global Nix channel is assumed.

The tools are `rg`, `btop`, `hx`, `lazygit`, `yazi`, and `zoxide` with working
`z`, plus Git, fzf, file/preview/archive helpers, LLVM/CMake/Make, Python
LSP/format/debug tools, and Rust compiler/LSP/format/lint tools required by the
editor config. Fixed Nixpkgs revisions and source hashes prevent silent package upgrades.
Helix uses its packaged runtime and grammars. Intel macOS selects a separate
26.05 pin because the newer Nixpkgs line dropped that platform. That stable line
is maintained upstream only through the end of 2026; it needs a future support
decision rather than an assumption of permanent Intel support.

Nix builds copies of the repository's Helix, Lazygit and Yazi configs, adapting
clangd to PATH, rustfmt to its packaged version, and Yazi's section to `[mgr]`.
At shell entry, those configs are copied again into a **writable private temporary
directory**. XDG paths, Lazygit's explicit config directory, Yazi's config path,
and Zsh's startup directory point there. Nothing is copied or symlinked over
`~/.config`, `~/Library`, `.zshrc`, or system configs. Original home startup files
are not sourced. Config changes in this shell disappear when it exits; edit the
source in your checkout and re-enter to keep a change.

The prompt, cursor shape and fzf integration are adapted from `.zshrc`; its
machine-specific paths, external hooks and `cd ~` are omitted. Desktop, terminal,
IDE, Claude, Neovim and Emacs setups remain reference files. Global home
clang-format/clang-tidy/clangd files are not installed; project-specific configs
continue to work. This shell does not launch or configure those desktop apps.

Your real HOME remains accessible, including your normal Git credentials/config.
**Intentional project edits and any writes made by commands you run can persist.**
This is environment isolation, not filesystem isolation. Tools launched from
another terminal or GUI do not inherit this shell's PATH/config variables.

### Daily use, multiple shells, and cache

```sh
rg --version
hx README.md
lazygit                    # inside a Git repository
yazi
btop
cd /path/to/my-project
z /path/to/my-project       # learns and visits it
cd /tmp
z my-project               # jumps to a learned directory
exit                       # or Ctrl-D
```

Open as many shells as you like in separate tabs. Their configs, history, tool
state and zoxide databases are separate; the Nix package cache is shared. A
nested shell also works, reusing the same Nix runtime and store. Let the first
rootless bootstrap finish before opening more shells, since the bundled backend
initializes its cache on first use.
Ctrl-C interrupts a foreground command; it normally leaves the shell running.
On normal exit, its temporary directory is removed. A force kill or power loss
can leave `dotfiles-session.*` or `dotfiles-bootstrap.*` under your temporary
directory; remove only directories belonging to sessions that have ended.

Caches intentionally persist. System Nix uses its normal `/nix` store/cache.
Rootless Linux defaults to `${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-nix`, including
its versioned executable and `.nix-portable` store. Set an absolute
`DOTFILES_CACHE_HOME` before running to choose another rootless cache location.
The backend/Nix may also use their standard user download caches. Existing
config files and the parent shell's PATH are not rewritten. To remove the
rootless cache, first exit **all** its shells, then deliberately delete only the
chosen `dotfiles-nix` directory; the next run downloads again. Do not delete an
active shell's store. Exiting never uninstalls system Nix or garbage-collects
anyone's environments. See [Nix garbage collection](https://nix.dev/manual/nix/stable/command-ref/nix-collect-garbage)
before managing a system installation's shared store.

### Manual review

No CI or new test files are included in this PR. Validation evidence and remaining
platform gaps are recorded in its description. To test a command and return:

```sh
sh ./install.sh --command 'rg --version; hx --version; type z'
```

1. Record your host PATH/tool locations and checksums of existing `.zshrc`, Helix,
   Lazygit and Yazi configs. Run from a project outside your checkout, ideally
   with spaces in its path. On Linux without Nix, confirm rootless startup asks
   for no sudo and creates no host `/nix`. On Mac, review/authenticate the Nix
   installation plan yourself if needed.
2. In the shell run `command -v rg hx lazygit yazi zoxide`, open each tool, and try
   `z` after learning a project. `hx --health cpp` should find packaged clangd.
   Run `lazygit --print-config-dir`; it should point inside `$DOTFILES_SESSION`.
3. Inspect `$XDG_CONFIG_HOME/helix/config.toml`. Edit the temporary copy, exit,
   and re-enter; your repo and original home config should be unchanged.
4. Open another shell/tab. Interrupt `sleep 30` using Ctrl-C, then leave with
   `exit` or Ctrl-D. The other shell should still work. Compare the host paths
   and checksums recorded earlier; temporary configs should disappear while
   intentional project edits and package caches remain.
5. Test both the cloned entry and pasted full script. During PR review set
   `DOTFILES_REF=ali/portable-nix-shell`; after merge unset it to test `main`.

For background, see [Nix development environments](https://nix.dev/tutorials/first-steps/declarative-shell.html).
For distro-managed Nix or WSL setup alternatives, consult the
[official installation guide](https://nix.dev/install-nix.html). Keep each project's
own dependencies in its own Nix file when useful; this is your general tools shell.

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

- `home/.clang-format` combines the live global LLVM-based style with sgame's
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
