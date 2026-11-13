#!/usr/bin/env python3
"""Exercise real fd/zoxide with an isolated directory tree and database."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile


script = Path(__file__).resolve().parents[1] / "scripts/seed-zoxide.py"
with tempfile.TemporaryDirectory(prefix="zoxide-seed-test-") as directory:
    base = Path(directory).resolve()
    root = base / "home with spaces"
    root.mkdir()
    depth5 = root / "one/two/three/four/five"
    depth6 = depth5 / "six"
    depth6.mkdir(parents=True)
    for name in (".hidden", "node_modules", "build", "Library", "target"):
        (root / name / "excluded").mkdir(parents=True)
    outside = base / "outside"
    (outside / "linked-child").mkdir(parents=True)
    (root / "symlink").symlink_to(outside, target_is_directory=True)
    (root / "ignored").mkdir()
    (root / ".ignore").write_text("ignored/\n")
    visited = root / "visited"
    visited.mkdir()
    env = dict(os.environ, _ZO_DATA_DIR=str(base / "state"),
               DOTFILES_ZOXIDE_ROOT=str(root), DOTFILES_ZOXIDE_DEPTH="5")
    # Do not inherit host settings that alter ranking or exclude test paths.
    for key in ("_ZO_EXCLUDE_DIRS", "_ZO_MAXAGE", "_ZO_RESOLVE_SYMLINKS"):
        env.pop(key, None)

    def run(*args):
        return subprocess.check_output(args, env=env, text=True)

    def seed(*args):
        return run(sys.executable, str(script), *args)

    def entries():
        return set(run("zoxide", "query", "--list").splitlines())

    run("zoxide", "add", "--score", "5", str(visited))
    before = run("zoxide", "query", "--score", "visited")
    seed()
    indexed = entries()
    assert str(depth5) in indexed and str(depth6) not in indexed, indexed
    assert str(visited) in indexed
    for name in (".hidden", "node_modules", "build", "Library", "target", "symlink", "ignored"):
        assert not any(Path(p).is_relative_to(root / name) for p in indexed), name
    assert run("zoxide", "query", "--score", "visited") == before

    new = root / "new-project"
    new.mkdir()
    assert seed() == ""  # no rescan on ordinary entry
    assert str(new) not in entries()
    seed("--refresh")
    assert str(new) in entries()
    assert run("zoxide", "query", "--score", "visited") == before
    unchanged = run("zoxide", "query", "--list", "--score")
    seed("--refresh")
    assert run("zoxide", "query", "--list", "--score") == unchanged

    # A removed database must be rebuilt even when its old seed marker remains.
    (base / "state/db.zo").unlink()
    seed()
    assert str(depth5) in entries()

    env["DOTFILES_ZOXIDE_DEPTH"] = "0"
    disabled = root / "disabled-project"
    disabled.mkdir()
    seed("--refresh")
    assert str(disabled) not in entries()

print("PASS: depth 5, exclusions, spaces, symlinks, persistence, refresh, rankings, opt-out")
