#!/usr/bin/env python3
"""Seed the dotfiles zoxide DB once, without inflating learned rankings."""
import argparse
import fcntl
import hashlib
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true", help="scan again for new directories")
    args = parser.parse_args()
    try:
        depth = int(os.environ.get("DOTFILES_ZOXIDE_DEPTH", "5"))
    except ValueError:
        parser.error("DOTFILES_ZOXIDE_DEPTH must be an integer")
    if depth == 0:
        return
    if depth < 0:
        parser.error("DOTFILES_ZOXIDE_DEPTH must be zero or positive")
    root = Path(os.environ.get("DOTFILES_ZOXIDE_ROOT", str(Path.home()))).expanduser()
    if not root.is_absolute() or not root.is_dir():
        parser.error("DOTFILES_ZOXIDE_ROOT must be an existing absolute directory")
    root = root.resolve()
    # Require the session's dedicated database; never fall back to the host DB.
    state = Path(os.environ["_ZO_DATA_DIR"])
    if not state.is_absolute():
        parser.error("_ZO_DATA_DIR must be absolute")
    state.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha256(f"v1\0{root}\0{depth}".encode()).hexdigest()[:20]
    marker = state / f".seed-{key}.done"
    # Serialize first launches/refreshes so the same seed is not added twice.
    with (state / ".seed.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if marker.exists() and (state / "db.zo").is_file() and not args.refresh:
            return
        command = ["fd", "--type", "directory", "--max-depth", str(depth),
                   "--absolute-path", "--print0", "--one-file-system"]
        for name in ("Library", "node_modules", "vendor", "target", "venv",
                     "__pycache__", "build", "cmake-build*", "CMakeFiles", "cache", "Cache"):
            command.extend(["--exclude", name])
        # fd skips hidden folders, symlinks and ignored directories by default.
        scan = subprocess.run([*command, ".", str(root)], check=True, capture_output=True)
        known = subprocess.run(["zoxide", "query", "--list", "--all"], capture_output=True)
        if known.returncode not in (0, 1):
            raise RuntimeError(known.stderr.decode(errors="replace"))
        if known.returncode == 1 and known.stderr.strip() not in (b"", b"zoxide: no match found"):
            raise RuntimeError(known.stderr.decode(errors="replace"))
        existing = set(known.stdout.splitlines())
        paths = sorted({p.rstrip(b"/") for p in scan.stdout.split(b"\0") if p})
        fresh = [p for p in paths if p not in existing and b"\n" not in p and b"\r" not in p]
        for start in range(0, len(fresh), 100):
            # Low initial rank lets real visits outrank the speculative index.
            subprocess.run([b"zoxide", b"add", b"--score", b"0.01", b"--",
                            *fresh[start:start + 100]], check=True)
        marker.write_text(f"{root}\ndepth={depth}\n")
        print(f"zoxide: seeded {len(fresh)} new directories (depth {depth}).")


if __name__ == "__main__":
    main()
