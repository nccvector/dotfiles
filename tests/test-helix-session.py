#!/usr/bin/env python3
"""Run inside install.sh --command to exercise the real Helix session."""
import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time
import tomllib


config_dir = Path(os.environ["XDG_CONFIG_HOME"]) / "helix"
runtime = config_dir / "runtime"
assert runtime.is_dir() and not runtime.is_symlink(), runtime
assert (runtime / "themes/gruvbox_dark_hard.toml").is_file()
assert (runtime / "themes/gruvbox.toml").is_file()  # inherited theme
assert (runtime / "queries/bash/highlights.scm").is_file()
assert (runtime / "grammars/bash.so").is_file()
assert not any(p.is_symlink() for p in runtime.rglob("*")), "runtime must be a copy"

config = tomllib.loads((config_dir / "config.toml").read_text())
assert config["theme"] == "gruvbox_dark_hard"
assert config["editor"]["true-color"] is True
assert config["editor"]["cursor-shape"]["select"] == "underline"
assert config["editor"]["inline-diagnostics"]["other-lines"] == "disable"
assert "whitespace" not in config["editor"]  # use the Mac's defaults
assert config["keys"]["normal"]["space"]["="] == ":format"

# --health alone does not initialize the terminal or prove the theme loaded.
# Open the real editor in a PTY with no COLORTERM (as on many SSH/tmux hosts).
with tempfile.TemporaryDirectory() as directory:
    sample = Path(directory) / "sample.sh"
    sample.write_text('# a spaced comment\nprintf "hello world\\n"\n')
    log = Path(directory) / "helix.log"
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
    env = dict(os.environ, TERM="xterm-256color")
    env.pop("COLORTERM", None)
    process = subprocess.Popen(
        ["hx", "-vv", "--log", str(log), str(sample)],
        stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True,
    )
    os.close(slave)
    output = bytearray()
    deadline = time.monotonic() + 30
    quit_sent = False
    try:
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not chunk:
                    break
                output.extend(chunk)
                # Answer terminal capability queries without a real terminal.
                if b"\x1b[6n" in chunk:
                    os.write(master, b"\x1b[1;1R")
                if not quit_sent and b"sample.sh" in output:
                    os.write(master, b":quit!\r")
                    quit_sent = True
            if process.poll() is not None:
                break
        assert quit_sent, "Helix never displayed the file"
        assert process.wait(timeout=5) == 0, output.decode(errors="replace")
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        os.close(master)
    assert b"48;2;29;32;33" in output, "Gruvbox hard RGB background was not rendered"
    assert "·".encode() not in output, "Space markers were rendered"
    logs = log.read_text() if log.exists() else ""
    assert "Failed to load theme" not in logs, logs
    assert "Failed to parse" not in logs, logs

print("PASS: copied runtime, inherited Gruvbox theme, Bash grammar, Mac settings, RGB rendering without COLORTERM")
