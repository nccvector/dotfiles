# Ubuntu development setup

The installation checklist for a fresh Ubuntu development machine using Bash,
Helix, and these dotfiles. It covers the Ubuntu 24.04 setup from 2026-10-01 and
the Ubuntu 20.04 setup from 2026-10-02, plus the tools requested for future installs.

**Status:** the recorded baseline was installed and checked on both systems.
Lazygit, btop, Yazi, and the permanent Rust, Zig, and Go toolchains are additions
to this checklist; this document does not imply they have been installed yet.
Version numbers in the history section record those installs, rather than a
requirement to use those versions forever. Check compatibility before upgrading.
Upstream installation instructions were checked on 2026-10-02.

## Fresh installation checklist

- [ ] Confirm Ubuntu version and CPU architecture; configure SSH access.
- [ ] Install the common packages and the appropriate compiler/Python tools.
- [ ] Install Helix with its matching runtime, lazygit, btop, and Yazi.
- [ ] Install language tools for C, C++, Python, Rust, Zig, and Go.
- [ ] Back up existing configuration, apply the Linux dotfiles, and configure Bash.
- [ ] Set Git identity and run the verification checklist at the end.

ROS distributions, NVIDIA drivers, CUDA, Docker, and project dependencies belong
to separate project-specific setup steps. ROS Noetic was already present on the
Ubuntu 20.04 system; the development-tools install did not install it.

## 1. System and SSH

Run on Ubuntu:

```bash
cat /etc/os-release
uname -m
sudo apt update
sudo apt install openssh-server
sudo systemctl enable --now ssh
systemctl is-active ssh
hostname -I
```

If UFW is active, allow the SSH service before connecting. From the Mac, copy
the intended public key with `ssh-copy-id` if available, or append that public
key to the Ubuntu account's `~/.ssh/authorized_keys`. Use directory permissions
`700` for `~/.ssh` and `600` for `authorized_keys`. Keep private keys on the Mac.

Add an entry to the Mac's `~/.ssh/config` using the actual username, address,
and key path. For dual boot, use separate aliases and `HostKeyAlias` values for
each OS: they have distinct SSH host keys even if they share an IP address.
Verify the host fingerprint when first connecting.

## 2. Common packages

These packages were included in both recorded development setups:

| Purpose | Packages |
| --- | --- |
| Git and downloads | `git`, `curl`, `ca-certificates` |
| Archive utilities | `unzip`, `xz-utils` |
| Shell and search | `bash-completion`, `ripgrep`, `fd-find`, `fzf` |
| Terminal and inspection | `tmux`, `htop`, `jq`, `tree`, `rsync` |
| Build tools | `build-essential`, `cmake`, `ninja-build`, `pkg-config` |
| Python foundation | `python3`, `python3-venv`, `python3-pip`, `pipx` |
| Debugging | `gdb`, plus LLDB in the LLVM section |

```bash
sudo apt install \
  git curl ca-certificates unzip xz-utils bash-completion \
  ripgrep fd-find fzf tmux htop jq tree rsync \
  build-essential cmake ninja-build pkg-config gdb \
  python3 python3-venv python3-pip pipx
mkdir -p "$HOME/.local/bin" "$HOME/.local/share"
```

[Ripgrep](https://github.com/BurntSushi/ripgrep) is installed as the command
`rg`. Ubuntu's `fd-find` package provides `fdfind`; expose it as `fd` in
`~/.local/bin`. Inspect any existing destination before creating a symlink.

```bash
ln -s /usr/bin/fdfind "$HOME/.local/bin/fd"
```

## 3. C and C++ tools

Install Clang, clangd, clang-format, clang-tidy, LLDB, and its DAP adapter.
LLVM 18 was used on both recorded systems. The original Ubuntu 24.04 install
used the unversioned APT packages; Ubuntu 20.04 used these explicit packages:

```bash
sudo apt install clang-18 clangd-18 clang-format-18 clang-tidy-18 lldb-18
```

Check `apt-cache policy` first. LLVM 18 was available from the configured
official Ubuntu repositories on the tested 20.04 machine; availability on a
fresh machine depends on its enabled repositories and updates.

Helix needs command names on PATH. Where only versioned executables exist,
create user symlinks after checking the destinations:

```bash
for tool in clang clang++ clangd clang-format clang-tidy lldb lldb-dap; do
  test -x "/usr/bin/$tool-18" || continue
  ln -s "/usr/bin/$tool-18" "$HOME/.local/bin/$tool"
done
```

`bootstrap-c` requires CMake 3.21 or newer. Ubuntu 24.04 supplied 3.28.3;
Ubuntu 20.04 supplied 3.16.3, so a user-level CMake 3.28.3 was installed through
the isolated environment below. Leave `/usr/bin/cmake` available for projects
that require the system version.

Generate `compile_commands.json` for each C/C++ project so clangd sees its real
compiler flags. For an ordinary CMake project, configure with
`-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` and make that database discoverable from
the project root. The repository's `bootstrap-c` handles this for its templates.

## 4. Python tools

### Ubuntu 24.04

The recorded install used distribution packages:

```bash
sudo apt install python3-pylsp black python3-debugpy
```

Use project virtual environments for project dependencies. For extra editor
plugins, create a dedicated tools environment rather than changing system pip
packages.

### Ubuntu 20.04

Keep the system Python 3.8 for ROS Noetic. The recorded setup used the following
compatible versions in a private tools environment:

```bash
python3 -m venv "$HOME/.local/share/ubuntu-dev/python-tools"
tools_env="$HOME/.local/share/ubuntu-dev/python-tools"
"$tools_env/bin/python" -m pip install 'pip==24.3.1'
"$tools_env/bin/python" -m pip install \
  'python-lsp-server==1.10.0' 'black==24.2.0' 'debugpy==1.8.1' \
  'cmake==3.28.3' 'tomli==2.0.1'
"$tools_env/bin/python" -m pip check
for tool in pylsp black cmake ctest cpack; do
  ln -s "$tools_env/bin/$tool" "$HOME/.local/bin/$tool"
done
```

Review existing environments and symlinks before applying this recipe again.
Current releases of these Python tools may need a newer Python; do not blindly
replace the 20.04 pins with `latest`. The server's executable is `pylsp`.
[Python LSP installation and plugins](https://github.com/python-lsp/python-lsp-server).

Black provides external formatting. Installing Black does not also install the
`python-lsp-black` plugin. Similarly, Ruff and mypy settings require their
corresponding plugins in the same environment as `pylsp`.

`debugpy` is a Python module, not necessarily a standalone executable. On
20.04, invoke it with `"$tools_env/bin/python" -m debugpy`. When configuring
Helix debugging, use that environment's **absolute Python path** with
`-m debugpy.adapter`; `/usr/bin/python3` cannot see modules installed only there.
The recorded installs did not configure or test Python debugging in Helix.

## 5. Helix and its runtime

[Helix](https://github.com/helix-editor/helix) was installed as `hx`, with the
repository's theme, UI settings, and keybindings. Both setups used
[release 25.07.1](https://github.com/helix-editor/helix/releases/tag/25.07.1).

On Ubuntu 24.04, the official Linux release binary worked. Select the asset for
the machine's architecture and verify its published checksum before extraction.
Install the entire release, including its matching runtime:

```text
~/.local/share/helix/<version>/hx
~/.local/share/helix/<version>/runtime/
~/.local/bin/hx -> the installed hx
~/.config/helix/runtime -> the matching runtime directory
```

On Ubuntu 20.04, that release binary required newer glibc symbols than the
system's glibc 2.31. We built the same release from source using Rust 1.82.0,
with `HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1`, and paired it with the
checksum-verified official runtime. All 245 bundled grammar libraries loaded
on the tested system. The temporary Rust build toolchain was removed afterward;
this did not install a permanent Rust development environment.

The source-build dependency list also included `libssl-dev`:

```bash
sudo apt install libssl-dev
```

For future 20.04 installs, test the selected binary first. If incompatible,
build a pinned release locally using its required Rust version and verify its
runtime grammars. Avoid replacing the OS glibc to accommodate an editor.
See [Helix source installation](https://docs.helix-editor.com/install.html).

## 6. Additional everyday tools

These tools are now part of the desired fresh-install list. Install them when
missing, and record the selected versions after verification.

| Tool | Installation route for Ubuntu 20.04 and 24.04 | Check |
| --- | --- | --- |
| [Lazygit](https://github.com/jesseduffield/lazygit#debian-and-ubuntu) | Official release archive for the CPU architecture; put the binary in `~/.local/bin`. Upstream's direct Ubuntu APT route applies to 25.10 and later. | `lazygit --version` |
| [btop](https://github.com/aristocratos/btop#compilation-linux) | Use `sudo apt install btop` when a suitable candidate exists; otherwise use a compatible official release or build a pinned tag. | `btop --version`, then launch it |
| [Yazi](https://github.com/sxyazi/yazi) | Official release archive; install both `yazi` and `ya`. Prefer checking a musl build on older Ubuntu to avoid newer glibc requirements. | `yazi --version`, `ya --version` |
| [Ripgrep](https://github.com/BurntSushi/ripgrep) | Already in the common APT list. | `rg --version` |
| [Helix](https://github.com/helix-editor/helix) | Already in the editor section. | `hx --version`, `hx --health` |

Download release assets from the linked official projects, verify available
checksums/signatures, and retain the exact version and architecture in the
installation record. A newer release being available does not prove it runs
on Ubuntu 20.04.

### btop source compatibility

The current upstream Linux source requires GCC 14 or Clang 19 or newer, so the
recorded LLVM 18 baseline alone is insufficient for building current `main`.
Use the packaged/release binary by default. If compiling, follow the
[Linux build instructions](https://github.com/aristocratos/btop#compilation-linux)
for the chosen tag and install with a user prefix. Check GPU telemetry separately;
successful CPU monitoring does not prove GPU support works.

### Yazi dependencies

Install `file` for type detection. Add `ffmpeg`, `poppler-utils`, `jq`, `fd`,
`rg`, an appropriate non-standalone 7-Zip package, and a clipboard utility
(`xclip` for X11 or `wl-clipboard` for Wayland). Optional enhancements include
zoxide, resvg, ImageMagick, and a Nerd Font in the terminal displaying Yazi.

Check the [current dependency requirements](https://yazi-rs.github.io/docs/installation/):
the documented optional fzf integration requires at least 0.53.0 and certain
ImageMagick previews require at least 7.1.1. The older distribution packages
used in the baseline may not enable every preview/navigation feature. Verify
archive extraction and previews instead of assuming package presence is enough.

## 7. Language support checklist

Install the compiler/interpreter, language server, and formatter for each
language. Debug adapter availability is a separate check.

| Language | Compiler or runtime | Language server | Formatting and linting | Debugging |
| --- | --- | --- | --- | --- |
| C | Clang and GCC | `clangd` | `clang-format`, `clang-tidy` | `lldb-dap`; GDB for CLI use |
| C++ | Clang++ and G++ | `clangd` | `clang-format`, `clang-tidy` | `lldb-dap`; GDB for CLI use |
| Python | System Python plus project venvs | `pylsp` | Black; optional Ruff/mypy plugins | `debugpy.adapter` through the correct Python |
| Rust | `rustup`, `rustc`, Cargo | `rust-analyzer` | `rustfmt`, Clippy | `lldb-dap`; verify Rust debugger support |
| Zig | Project-compatible Zig | Compatible `zls` | `zig fmt` | LLDB/GDB for CLI use; test any DAP setup |
| Go | Supported Go toolchain | `gopls` | `gofmt`; optional `goimports` | Optional Delve (`dlv`) |

### Rust

Install rustup using the [official instructions](https://rustup.rs/), then add
the [toolchain components](https://rust-lang.github.io/rustup/concepts/components.html):

```bash
rustup toolchain install stable
rustup component add --toolchain stable rust-analyzer rustfmt clippy rust-src
```

Keep project versions in `rust-toolchain.toml` when required. The Mac dotfiles
currently invoke nightly rustfmt; on Ubuntu, select a stable formatter or
install nightly deliberately. The Linux example below uses edition 2021;
change its argument for projects using a different edition. Cargo formatting
and editor formatting should agree.
[Rustfmt configuration](https://github.com/rust-lang/rustfmt).

### Zig

Install Zig from its [official downloads](https://ziglang.org/download/), then
use the [ZLS installation guide](https://zigtools.org/zls/install/) to select a
matching release family. Pair stable Zig with stable ZLS; pair development
builds deliberately. Do not independently install the newest version of each.
Expose `zig` and `zls` on PATH, and record both versions.

### Go

Install a supported Go release using the [official installation guide](https://go.dev/doc/install),
then install [gopls](https://go.dev/gopls/):

```bash
go install golang.org/x/tools/gopls@latest
```

This is a fresh-install command: record the resolved gopls version, or replace
`latest` with that version when reproducing a setup. Keep Go compatible with
gopls's support policy. `gofmt` ships with Go; expose the Go toolchain's `bin`
directory and `$(go env GOPATH)/bin` on PATH. Optional import formatting and
debugging tools are `golang.org/x/tools/cmd/goimports` and
`github.com/go-delve/delve/cmd/dlv`.

## 8. Apply the dotfiles for Linux

Clone [nccvector/dotfiles](https://github.com/nccvector/dotfiles) into
`~/dotfiles`, or inspect an existing checkout without overwriting its changes.
Record the chosen commit. Both previous installs used published revision
`30108da194a2ec52f1956a7fbec2273b81963aac`; unpublished Mac edits were not copied.

Back up each destination before copying or replacing it. For example, copy
existing files into a dated `~/.ubuntu-dev-backup-<timestamp>/` directory while
preserving their relative paths. Review symlinks as well as regular files.

| Repository source | Ubuntu destination and adjustment |
| --- | --- |
| `home/.config/helix/config.toml` | `~/.config/helix/config.toml`; theme, UI, keybindings |
| `home/.config/helix/languages.toml` | Adapt into `~/.config/helix/languages.toml`; replace the Homebrew clangd path and select installed language tools |
| `home/.clang-format` | `~/.clang-format`; validate against installed clang-format |
| `home/.clang-tidy` | `~/.clang-tidy`; check enabled diagnostics against installed LLVM |
| `home/.config/clangd/config.yaml` | `~/.config/clangd/config.yaml`; omit unsupported keys for the chosen clangd |
| `scripts/bootstrap-c` | Install executable as `~/.local/bin/bootstrap-c` |

For LLVM 18, omit `Includes.AnalyzeAngledIncludes` from the **installed** clangd
config if present: it produced an unknown-key warning in the original setup.
Ubuntu 20.04's installed copy was adjusted; the repository copy was preserved.
Take the formatting policy from the selected repository revision, rather than
assuming it matches a previously installed copy.

Keep Ubuntu's `.bashrc` and append the development block below. The repository
also contains Mac-specific configurations; do not copy the entire `home/` tree
over an Ubuntu home directory or replace Bash with `.zshrc`.

### Linux Helix language configuration

The following is a proposed six-language configuration. The recorded installs
configured C, C++, and Python only. Merge it with existing settings after backup,
and check it against the installed Helix version.

```toml
[language-server.clangd]
command = "clangd"
args = ["--clang-tidy", "--enable-config", "--fallback-style=none"]

[language-server.pylsp]
command = "pylsp"

[language-server.rust-analyzer]
command = "rust-analyzer"
config = { check = { command = "clippy" } }

[language-server.zls]
command = "zls"

[language-server.gopls]
command = "gopls"

[[language]]
name = "c"
language-servers = ["clangd"]
auto-format = true
formatter = { command = "clang-format", args = ["--style=file", "--assume-filename=.c"] }

[[language]]
name = "cpp"
language-servers = ["clangd"]
auto-format = true
formatter = { command = "clang-format", args = ["--style=file", "--assume-filename=.cpp"] }

[[language]]
name = "python"
language-servers = ["pylsp"]
auto-format = true
formatter = { command = "black", args = ["-", "--quiet", "--line-length=120"] }

[[language]]
name = "rust"
language-servers = ["rust-analyzer"]
auto-format = true
formatter = { command = "rustfmt", args = ["--edition", "2021"] }

[[language]]
name = "zig"
language-servers = ["zls"]
auto-format = true
formatter = { command = "zig", args = ["fmt", "--stdin"] }

[[language]]
name = "go"
language-servers = ["gopls"]
auto-format = true
formatter = { command = "gofmt" }
```

This uses external stdin/stdout formatters and PATH-based language servers.
[Helix language configuration](https://docs.helix-editor.com/languages.html).
For Python imports/completions, make pylsp aware of the project environment;
installing the server alone does not make project packages available to it.

Optional parity with the Mac configuration: `typos-lsp`, `python-lsp-ruff`,
`python-lsp-black`, `pylsp-mypy`, and flake8. Install compatible versions before
enabling their settings. These were not part of the recorded Ubuntu baseline.

## 9. Bash integration and Git identity

Append once to `~/.bashrc`, after making a backup. Add the actual Go compiler
directory separately if it is not already on PATH.

```bash
for dev_bin in "$HOME/go/bin" "$HOME/.cargo/bin" "$HOME/.local/bin"; do
  case ":$PATH:" in
    *":$dev_bin:"*) ;;
    *) export PATH="$dev_bin:$PATH" ;;
  esac
done
export EDITOR=hx
export VISUAL=hx

if [[ -r /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
fi
if [[ -r /usr/share/bash-completion/completions/fzf ]]; then
  source /usr/share/bash-completion/completions/fzf
elif [[ -r /usr/share/doc/fzf/examples/completion.bash ]]; then
  source /usr/share/doc/fzf/examples/completion.bash
fi
```

If fzf was installed through an upstream release instead of APT, use that
version's Bash integration instructions and paths. Check both completion and
Ctrl-R/Ctrl-T/Alt-C. Reload with `source ~/.bashrc`; the login shell stays Bash.

Set Git `user.name` and `user.email` to the intended identity, then verify with
`git config --global --get user.name` and `git config --global --get user.email`.
They were not set by the recorded development installers.

## 10. Installation history

These are recorded results, not a fresh audit of the machines today.

| Component | Ubuntu 24.04 install, 2026-10-01 | Ubuntu 20.04 install, 2026-10-02 |
| --- | --- | --- |
| OS tested | 24.04.3 LTS, x86_64 | 20.04.6 LTS, x86_64 |
| Final shell | Bash; `.bashrc` integration | Bash; `.bashrc` integration |
| Git | 2.43.0 | 2.25.1 |
| Helix | 25.07.1, official binary/runtime | 25.07.1, local source build/matching official runtime |
| Clang/clangd/clang-format | 18.1.3 | 18.1.8 |
| CMake selected by PATH | 3.28.3, APT | 3.28.3, tools venv; system 3.16.3 retained |
| System Python | 3.12.3 | 3.8.10 |
| Python editor tools | APT pylsp, Black, debugpy | pylsp 1.10.0, Black 24.2.0, debugpy 1.8.1 |
| Other Python tools | venv, pip, pipx | venv, pip, pipx; tools venv pip 24.3.1, tomli 2.0.1 |
| Additional build dependency | Common build packages | `libssl-dev` for the source build |
| Dotfiles | Published revision `30108da194a2ec52f1956a7fbec2273b81963aac` | Same published revision |
| Applied configuration | Helix UI and C/C++/Python, global clang settings, `bootstrap-c`, `fd`, Bash/fzf | Same, with Linux/LLVM 18 compatibility adjustments |

Both installs passed C11/C++20 compile-and-run checks, Helix C/C++/Python
health checks, TOML parsing, clang-format configuration loading, Python venv
checks, and `bootstrap-c` Debug/Release generation/build/run checks.

Ubuntu 20.04 also passed interactive Helix startup over SSH, Python tools
dependency checks, warning-free clangd configuration loading, fzf binding and
completion checks, and system-Python `rospy` import.

Recorded gaps and limits:

- Ubuntu 24.04 still needed the unversioned `lldb-dap` command and the unsupported
  clangd include-analysis key removed from its installed config.
- Git identity and Helix Python debugging still needed configuration.
- Zsh had been installed during the initial 24.04 attempt; the final configuration
  was corrected to Bash. Zsh is not required by this checklist.
- Lazygit, btop, Yazi, and permanent Rust/Zig/Go development tools were not part
  of those baseline installs.
- Full debugger sessions, real project builds, ROS launches/simulation, and
  graphical desktop/NVIDIA behavior were not verified by these setup checks.

## 11. Verification and completion

Run from a fresh Bash terminal so PATH and shell initialization are exercised:

```bash
bash -n "$HOME/.bashrc"
printf 'EDITOR=%s VISUAL=%s\n' "$EDITOR" "$VISUAL"
for tool in git hx rg fd fzf tmux lazygit btop yazi ya \
  clang clang++ clangd clang-format clang-tidy lldb-dap \
  cmake ninja python3 pylsp black bootstrap-c \
  rustup rustc cargo rust-analyzer rustfmt zig zls go gopls gofmt; do
  command -v "$tool" || printf 'MISSING: %s\n' "$tool"
done
for language in c cpp python rust zig go; do
  hx --health "$language"
done
clang-format --style=file:"$HOME/.clang-format" --dump-config >/dev/null
```

- [ ] Open a file in each language; verify diagnostics, completion, navigation,
  and formatting. Health checks show discoverability, not full LSP behavior.
- [ ] Compile and run a small C and C++ program with warnings treated as errors.
- [ ] Generate a scratch project with `bootstrap-c`, build/run both presets,
  and confirm clangd uses its compilation database without config warnings.
- [ ] In project environments, run Python tooling, `cargo check`/`cargo clippy`,
  `zig build`, and `go test ./...` as applicable.
- [ ] Launch lazygit, btop, and Yazi; test Yazi previews and clipboard behavior.
- [ ] Test any configured debugger with a breakpoint and variable inspection.
- [ ] On ROS Noetic, verify system-Python `rospy` import after tool installation.
- [ ] Record tool versions, dotfiles commit, backup location, and remaining gaps.

The setup is complete when all required tools resolve in a fresh Bash session,
the six language environments work on representative files/projects, and any
unverified optional features are recorded explicitly.
