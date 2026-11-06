# Fixed revision: no channels, global package installation, or implicit updates.
{ system ? builtins.currentSystem }:
let
  # Current unstable dropped Intel macOS; keep its last supported stable line.
  source = if system == "x86_64-darwin" then {
    url = "https://github.com/NixOS/nixpkgs/archive/d70a468dc082082bedc027275b3b49ac7007c938.tar.gz";
    sha256 = "0j3s9phmrsafy64wwbwkqyjra323kc4xrbd7k45z7jc4yww82m5a";
  } else {
    url = "https://github.com/NixOS/nixpkgs/archive/6dadaf4375be35033e1c84395adbd53ff5fded96.tar.gz";
    sha256 = "1g9sadx7zszll972hlv78675vc5vz2iw8v9jzs4338ccx8gzp48g";
  };
  pkgs = import (builtins.fetchTarball source) { inherit system; };
  python = pkgs.python3.withPackages (p: with p; [
    python-lsp-server python-lsp-ruff python-lsp-black pylsp-mypy black debugpy
  ]);
  configs = pkgs.runCommand "dotfiles-tool-configs" {} ''
    mkdir -p "$out/helix" "$out/lazygit" "$out/yazi"
    cat ${./home/.config/helix/config.toml} > "$out/helix/config.toml"
    sed 's|/opt/homebrew/opt/llvm/bin/clangd|clangd|; s/args = \["+nightly"\]/args = []/' \
      ${./home/.config/helix/languages.toml} > "$out/helix/languages.toml"
    cat ${./home/.config/lazygit/config.yml} > "$out/lazygit/config.yml"
    sed 's/^\[manager\]/[mgr]/' ${./home/.config/yazi/yazi.toml} > "$out/yazi/yazi.toml"
  '';
  session = pkgs.writeShellScript "dotfiles-session" ''
    set -euo pipefail
    umask 077
    session=$(mktemp -d "''${TMPDIR:-/tmp}/dotfiles-session.XXXXXXXX")
    cleanup() { rm -rf -- "$session"; }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    export DOTFILES_SESSION="$session"
    export XDG_CONFIG_HOME="$session/config" XDG_CACHE_HOME="$session/cache"
    export XDG_DATA_HOME="$session/data" XDG_STATE_HOME="$session/state"
    export ZDOTDIR="$session/zsh"
    # Share only navigation learning across launches; leave host zoxide data alone.
    export _ZO_DATA_DIR="$DOTFILES_STATE_HOME/zoxide"
    export HISTFILE="$session/zsh/history"
    export EDITOR=hx VISUAL=hx
    # Make the same Nix available for nested shells without changing tool precedence.
    export PATH="$PATH:$DOTFILES_NIX_BIN"
    unset HELIX_RUNTIME
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$ZDOTDIR" "$_ZO_DATA_DIR"
    mkdir -p "$XDG_CONFIG_HOME/helix" "$XDG_CONFIG_HOME/lazygit" "$XDG_CONFIG_HOME/yazi"
    for config in helix/config.toml helix/languages.toml lazygit/config.yml yazi/yazi.toml; do
        cat "${configs}/$config" > "$XDG_CONFIG_HOME/$config"
    done
    export YAZI_CONFIG_HOME="$XDG_CONFIG_HOME/yazi"
    export LG_CONFIG_FILE="$XDG_CONFIG_HOME/lazygit/config.yml"
    # Lazygit's macOS default ignores XDG, so explicitly redirect its entire directory.
    export CONFIG_DIR="$XDG_CONFIG_HOME/lazygit"
    cat > "$ZDOTDIR/.zshrc" <<'RC'
    setopt NO_GLOBAL_RCS
    export PS1='[dotfiles] %n@%m:%~ %# '
    eval "$(zoxide init zsh)"
    if [[ -t 0 && -t 1 ]]; then source <(fzf --zsh); fi
    precmd() { printf '\033[2 q' }
    preexec() { printf '\033[2 q' }
    RC
    if [[ -n ''${DOTFILES_COMMAND:-} ]]; then
        zsh -d -i -c "$DOTFILES_COMMAND"
    else
        printf '%s\n' 'Temporary dotfiles shell ready. Type exit or Ctrl-D to leave.'
        zsh -d -i
    fi

  '';
in pkgs.mkShell {
  passthru.bootstrapShell = pkgs.bashInteractive;
  packages = with pkgs; [
    bashInteractive zsh ncurses git ripgrep btop helix lazygit yazi zoxide
    fzf fd jq file unzip zip p7zip poppler ffmpeg imagemagick chafa
    clang-tools llvmPackages.clang cmake gnumake pkg-config
    python typos-lsp rust-analyzer rustc cargo rustfmt clippy
  ];
  # Never source the user's machine-specific HELIX_RUNTIME or shell rc files.
  shellHook = ''
    unset HELIX_RUNTIME
    export DOTFILES_RUNNER=${session}
  '';
}
