# Fixed revision: no channels, global package installation, or implicit updates.
let
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6dadaf4375be35033e1c84395adbd53ff5fded96.tar.gz";
  }) {};
  python = pkgs.python3.withPackages (p: with p; [
    python-lsp-server python-lsp-ruff python-lsp-black pylsp-mypy black debugpy
  ]);
in pkgs.mkShell {
  packages = with pkgs; [
    bashInteractive zsh git ripgrep btop helix lazygit yazi zoxide
    fzf fd jq file unzip zip p7zip poppler ffmpeg imagemagick chafa
    clang-tools llvmPackages.clang cmake gnumake pkg-config
    python typos-lsp rust-analyzer rustc cargo rustfmt clippy
  ];
  # Never source the user's machine-specific HELIX_RUNTIME or shell rc files.
  shellHook = ''
    unset HELIX_RUNTIME
  '';
}
