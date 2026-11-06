#!/bin/sh
# Copy this WHOLE file into a terminal, or run: sh ./install.sh
# The subshell keeps variables, traps, and directory changes out of your shell.
(
set -eu
umask 077
fail() { printf '%s\n' "dotfiles: $*" >&2; exit 1; }
fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl --fail --silent --show-error --location "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$1" -O "$2"
    else
        fail 'Install curl or wget first (macOS already includes curl).'
    fi
}
command_text=
case "${1:-}" in
    '') ;;
    --command) [ "$#" -eq 2 ] || fail 'Usage: sh install.sh [--command "commands"]'; command_text=$2 ;;
    --help) printf '%s\n' 'Usage: sh install.sh [--command "commands"]' 'Installs Nix if needed, then opens a temporary configured tools shell.'; exit 0 ;;
    *) fail 'Usage: sh install.sh [--command "commands"]' ;;
esac
work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap.XXXXXXXX")
cleanup() { rm -rf -- "$work"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Only a real local install.sh selects a checkout. Pasted text uses a snapshot.
repo=
if [ -f "$0" ] && [ "$(basename -- "$0")" = install.sh ]; then
    candidate=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
    if [ -f "$candidate/shell.nix" ] && [ -f "$candidate/nix/session" ]; then
        repo=$candidate
    fi
fi
if [ -z "$repo" ]; then
    # Override for reviewing an unmerged branch; normal use follows main.
    ref=${DOTFILES_REF:-main}
    case "$ref" in *[!a-zA-Z0-9_./-]*|'') fail 'Invalid DOTFILES_REF' ;; esac
    fetch "https://codeload.github.com/nccvector/dotfiles/tar.gz/$ref" "$work/repo.tar.gz"
    mkdir "$work/repo"
    tar -xzf "$work/repo.tar.gz" -C "$work/repo" --strip-components=1
    repo=$work/repo
fi
[ -f "$repo/shell.nix" ] && [ -f "$repo/nix/session" ] || fail 'Incomplete dotfiles checkout.'
# Discover an existing Nix without editing or sourcing any shell profile.
if ! command -v nix-shell >/dev/null 2>&1; then
    for bin in /nix/var/nix/profiles/default/bin "$HOME/.nix-profile/bin"; do
        if [ -x "$bin/nix-shell" ]; then PATH="$bin:$PATH"; export PATH; break; fi
    done
fi
if ! command -v nix-shell >/dev/null 2>&1; then
    # NixOS community installer: this flag REALLY skips shell profile changes.
    # The older nixos.org/nix/install daemon installer does not honor that flag.
    case "$(uname -s):$(uname -m)" in
        Darwin:arm64|Darwin:aarch64) platform=aarch64-darwin; expected=42cb8b257ace0bce5a5ee0d5bc36af47a6887004c00e8801940112c6e37beca3 ;;
        Linux:x86_64) platform=x86_64-linux; expected=60f39200fc2690bcf4da7ba3f8b2e4dee0118f487bc9f41cd4e153d1a02dce77 ;;
        Linux:aarch64|Linux:arm64) platform=aarch64-linux; expected=4f02039533e0912cb5e6f819a2abcac87d78e19b76e377c2ee98e5ec10402341 ;;
        *) fail 'Automatic Nix installation supports Apple Silicon macOS and x86_64/aarch64 Linux. Install Nix separately on this platform, then rerun.' ;;
    esac
    printf '%s\n' 'Nix is missing. Its installer will show a plan and ask for confirmation.' \
        'This creates /nix, build users, and a system daemon (and an APFS volume on macOS).' \
        'Existing shell profiles will not be modified. Administrator authentication may be required.'
    [ -t 0 ] || [ -r /dev/tty ] || fail 'Nix installation needs an interactive terminal.'
    fetch "https://github.com/NixOS/nix-installer/releases/download/2.35.4/nix-installer-$platform" "$work/nix-installer"
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$work/nix-installer" | cut -d ' ' -f 1)
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$work/nix-installer" | cut -d ' ' -f 1)
    else
        fail 'A SHA-256 verifier (sha256sum or shasum) is required.'
    fi
    [ "$actual" = "$expected" ] || fail 'Nix installer checksum mismatch; nothing was installed.'
    chmod 700 "$work/nix-installer"
    "$work/nix-installer" install --no-modify-profile </dev/tty
    PATH="/nix/var/nix/profiles/default/bin:$PATH"; export PATH
fi
command -v nix-shell >/dev/null 2>&1 || fail 'Nix installation did not provide nix-shell.'
export DOTFILES_ROOT="$repo" DOTFILES_COMMAND="$command_text"
# Keep the original working directory. No profile install or channel update.
# Purity here controls environment variables; this is NOT a filesystem sandbox.
nix-shell "$repo/shell.nix" --pure \
    --keep HOME --keep TERM --keep COLORTERM --keep SSH_AUTH_SOCK \
    --keep DOTFILES_ROOT --keep DOTFILES_COMMAND --keep TMPDIR \
    --run 'bash "$DOTFILES_ROOT/nix/session"'
)
