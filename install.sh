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
verify() {
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$1" | cut -d ' ' -f 1)
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$1" | cut -d ' ' -f 1)
    else
        fail 'A SHA-256 verifier (sha256sum or shasum) is required.'
    fi
    [ "$actual" = "$2" ] || fail 'Nix bootstrap checksum mismatch; refusing to execute it.'
}
nix_bin=
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
    if [ -f "$candidate/shell.nix" ]; then
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
[ -f "$repo/shell.nix" ] || fail 'Incomplete dotfiles checkout.'
# Discover an existing Nix without editing or sourcing any shell profile.
if ! command -v nix-shell >/dev/null 2>&1; then
    for bin in /nix/var/nix/profiles/default/bin "$HOME/.nix-profile/bin"; do
        if [ -x "$bin/nix-shell" ]; then PATH="$bin:$PATH"; export PATH; break; fi
    done
fi
if ! command -v nix-shell >/dev/null 2>&1; then
    case "$(uname -s):$(uname -m)" in
        Linux:x86_64) arch=x86_64; portable_hash=b409c55904c909ac3aeda3fb1253319f86a89ddd1ba31a5dec33d4a06414c72a ;;
        Linux:aarch64|Linux:arm64) arch=aarch64; portable_hash=af41d8defdb9fa17ee361220ee05a0c758d3e6231384a3f969a314f9133744ea ;;
        Linux:*) fail 'Rootless Linux bootstrap requires x86_64 or aarch64.' ;;
        Darwin:*) arch= ;;
        *) fail 'Supported hosts are Linux and macOS; Windows requires WSL2.' ;;
    esac
    if [ -n "$arch" ]; then
        # Linux: a private user cache, no root, daemon, systemd, or /nix changes.
        for utility in bash date readlink realpath base64 chmod ln find head; do
            command -v "$utility" >/dev/null 2>&1 || fail "Rootless Linux bootstrap needs $utility."
        done
        cache=${DOTFILES_CACHE_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-nix}
        case "$cache" in /*) ;; *) fail 'DOTFILES_CACHE_HOME must be an absolute path.' ;; esac
        case "$cache:$HOME" in *[[:space:]]*) fail 'nix-portable requires cache and HOME paths without whitespace.' ;; esac
        mkdir -p "$cache"
        portable="$cache/nix-portable-v012-$arch"
        if [ ! -e "$portable" ]; then
            fetch "https://github.com/DavHau/nix-portable/releases/download/v012/nix-portable-$arch" "$work/nix-portable"
            verify "$work/nix-portable" "$portable_hash"
            chmod 700 "$work/nix-portable"
            # Publish only a fully downloaded, verified executable.
            cp "$work/nix-portable" "$cache/.nix-portable-$$"
            mv "$cache/.nix-portable-$$" "$portable"
        fi
        verify "$portable" "$portable_hash"
        export NP_LOCATION="$cache" NP_RUNTIME=proot
        # Bundled Git avoids host-version assumptions and shared tmpbin symlink races.
        unset NP_GIT
        mkdir "$work/bin"
        ln -s "$portable" "$work/bin/nix-shell"
        ln -s "$portable" "$work/bin/nix-build"
        PATH="$work/bin:$PATH"; export PATH
        printf '%s\n' 'Using rootless Nix in the user cache (PRoot; no sudo or system changes).'
        # Initialize once, then expose this same Nix inside the virtual store.
        # Mixing a newer Nix into the portable store could change its DB format.
        nix-shell --version >/dev/null
        native_nix=$(find "$cache/.nix-portable/nix/store" -maxdepth 1 -type d -name '*-nix-2.20.6' | head -n 1)
        [ -n "$native_nix" ] || fail 'Cannot locate the bundled Nix runtime.'
        nix_bin="/nix/store/$(basename -- "$native_nix")/bin"
    else
        # NixOS community installer: this flag REALLY skips shell profile changes.
        # The older nixos.org/nix/install daemon installer does not honor that flag.
        case "$(uname -s):$(uname -m)" in
            Darwin:arm64|Darwin:aarch64) platform=aarch64-darwin; expected=42cb8b257ace0bce5a5ee0d5bc36af47a6887004c00e8801940112c6e37beca3 ;;
            *) fail 'Automatic macOS installation requires Apple Silicon. On Intel macOS install Nix separately, then rerun.' ;;
        esac
        printf '%s\n' 'Nix is missing. Its installer will show a plan and ask for confirmation.' \
            'This creates /nix, build users, a system daemon, and an APFS volume/mount setup.' \
            'Existing shell profiles will not be modified. Administrator authentication may be required.'
        ( : </dev/tty ) 2>/dev/null || fail 'Nix installation needs an interactive terminal.'
        fetch "https://github.com/NixOS/nix-installer/releases/download/2.35.4/nix-installer-$platform" "$work/nix-installer"
        verify "$work/nix-installer" "$expected"
        chmod 700 "$work/nix-installer"
        unset NIX_INSTALLER_NO_CONFIRM NIX_INSTALLER_FORCE
        "$work/nix-installer" install --no-modify-profile </dev/tty
        PATH="/nix/var/nix/profiles/default/bin:$PATH"; export PATH
    fi
fi
command -v nix-shell >/dev/null 2>&1 || fail 'Nix installation did not provide nix-shell.'
[ -n "$nix_bin" ] || nix_bin=$(dirname -- "$(command -v nix-shell)")
export DOTFILES_NIX_BIN="$nix_bin" DOTFILES_ROOT="$repo" DOTFILES_COMMAND="$command_text"
# Pin the entry Bash too: no channels, NIX_PATH, or host-Bash version assumption.
command -v nix-build >/dev/null 2>&1 || fail 'Existing Nix must also provide nix-build.'
NIX_BUILD_SHELL="$(nix-build "$repo/shell.nix" -A bootstrapShell --no-out-link)/bin/bash"
export NIX_BUILD_SHELL
# Keep the original working directory. No profile install or channel update.
# Purity here controls environment variables; this is NOT a filesystem sandbox.
nix-shell "$repo/shell.nix" --pure \
    --keep HOME --keep TERM --keep COLORTERM --keep SSH_AUTH_SOCK \
    --keep DOTFILES_ROOT --keep DOTFILES_COMMAND --keep DOTFILES_NIX_BIN --keep TMPDIR \
    --keep NIX_BUILD_SHELL --keep NIX_CONF_DIR --keep NIX_SSL_CERT_FILE --keep SSL_CERT_FILE \
    --run '"$DOTFILES_RUNNER"'
)
