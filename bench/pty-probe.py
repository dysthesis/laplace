#!/usr/bin/env python3
# A prompt is ready when its pattern matches or output stays quiet.
from __future__ import annotations

import argparse
import json
import os
import pty
import re
import secrets
import select
import signal
import struct
import sys
import termios
import time
import tty
import fcntl

# Remove terminal control sequences before prompt detection.
_ANSI = re.compile(
    rb"\x1b\[[0-9;?]*[ -/]*[@-~]"      # CSI
    rb"|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)"  # OSC terminator: BEL or ST
    rb"|\x1b[@-Z\\-_]"                 # 2-byte escapes
    rb"|[\x00-\x08\x0e-\x1f]"          # C0 controls other than whitespace
)


def strip_ansi(b: bytes) -> bytes:
    return _ANSI.sub(b"", b)


# Send replies to terminal queries so shells do not read probe keystrokes as replies.
_QUERY = re.compile(
    rb"\x1b\[(?:0)?c"                       # DA1
    rb"|\x1b\[>(?:0)?c"                     # DA2
    rb"|\x1b\[6n"                           # CPR (cursor position)
    rb"|\x1b\[5n"                           # DSR (device status)
    rb"|\x1b\]1[01];\?(?:\x07|\x1b\\)"      # OSC 10/11: foreground and background colours
    rb"|\x1b\[>(?:0)?q"                     # XTVERSION
    rb"|\x1bP\+q[0-9A-Za-z;]*\x1b\\"        # XTGETTCAP (termcap)
    rb"|\x1b\[\?u"                          # kitty keyboard flags query
)


def _reply_for(q: bytes) -> bytes:
    if q == b"\x1b[?u":
        return b"\x1b[?0u"                          # no kitty keyboard flags
    if q.startswith(b"\x1bP+q"):
        return b"\x1bP0+r\x1b\\"                    # XTGETTCAP: unsupported
    if q.startswith(b"\x1b[>") and q.endswith(b"q"):
        return b"\x1bP>|harness\x1b\\"             # XTVERSION
    if q.startswith(b"\x1b]1"):                     # OSC colour query
        digits = q[2:4]                            # b"10" for foreground, b"11" for background
        rgb = b"ffff/ffff/ffff" if digits == b"10" else b"0000/0000/0000"
        return b"\x1b]" + digits + b";rgb:" + rgb + b"\x07"
    if q.endswith(b"6n"):
        return b"\x1b[1;1R"                         # Cursor at row 1, column 1
    if q.endswith(b"5n"):
        return b"\x1b[0n"                           # terminal OK
    if q.startswith(b"\x1b[>") and q.endswith(b"c"):
        return b"\x1b[>0;10;1c"                     # DA2
    if q.endswith(b"c"):
        return b"\x1b[?1;2c"                        # DA1 (VT100 with AVO)
    return b""


class Pty:
    """An interactive shell in a pseudo-terminal."""

    def __init__(self, argv, env, cols, rows, raw=True):
        self.argv = argv
        self.env = env
        self.cols = cols
        self.rows = rows
        self.raw = raw
        self.pid = -1
        self.fd = -1
        self.buf = bytearray()           # All bytes read, with control sequences
        self.t0 = 0.0                    # Monotonic time at spawn
        self._qpos = 0                   # First byte not scanned for terminal queries

    def spawn(self):
        self.t0 = time.monotonic()
        pid, fd = pty.fork()
        if pid == 0:
            try:
                os.execvpe(self.argv[0], self.argv, self.env)
            except Exception as exc:  # pragma: no cover - child path
                os.write(2, f"exec failed: {exc}\n".encode())
                os._exit(127)
        self.pid = pid
        self.fd = fd
        # Prompt layout changes with the terminal width.
        winsz = struct.pack("HHHH", self.rows, self.cols, 0, 0)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, winsz)
        # Raw mode measures shell echo, not kernel echo.
        # If ECHO is off at startup, Readline suppresses echo. Use --no-raw for Readline.
        if self.raw:
            try:
                tty.setraw(self.fd)
            except termios.error:
                pass
        flags = fcntl.fcntl(self.fd, fcntl.F_GETFL)
        fcntl.fcntl(self.fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
        return self

    def _read_some(self) -> bytes:
        try:
            chunk = os.read(self.fd, 65536)
        except (BlockingIOError, InterruptedError):
            return b""
        except OSError:
            return b""           # The child or file descriptor is closed.
        if chunk:
            self.buf += chunk
        return chunk

    def _answer_queries(self):
        region = bytes(self.buf[self._qpos:])
        matches = list(_QUERY.finditer(region))
        if not matches:
            # A terminal query can span two reads.
            self._qpos = max(self._qpos, len(self.buf) - 6)
            return
        for m in matches:
            reply = _reply_for(m.group())
            if reply:
                try:
                    os.write(self.fd, reply)
                except OSError:
                    pass
        self._qpos += matches[-1].end()

    def write(self, data: bytes):
        os.write(self.fd, data)

    def pump_until(self, predicate, timeout_s, quiesce_s=None):
        """Read until a match, a quiet period or the timeout.

        Return (matched, t_event, quiesced). The quiet period starts after the first byte.
        t_event is the match time or the time of the last byte before the quiet period.
        """
        deadline = time.monotonic() + timeout_s
        last_byte_t = None
        start_len = len(self.buf)
        while True:
            now = time.monotonic()
            if now >= deadline:
                return (False, last_byte_t or now, False)
            wait = deadline - now
            if quiesce_s is not None and last_byte_t is not None:
                wait = min(wait, quiesce_s)
            r, _, _ = select.select([self.fd], [], [], max(0.0, wait))
            t = time.monotonic()
            if r:
                chunk = self._read_some()
                if chunk:
                    last_byte_t = t
                    self._answer_queries()
                    if predicate(strip_ansi(bytes(self.buf))):
                        return (True, t, False)
                    continue
                return (False, last_byte_t or t, False)
            if (
                quiesce_s is not None
                and last_byte_t is not None
                and (time.monotonic() - last_byte_t) >= quiesce_s
                and len(self.buf) > start_len
            ):
                return (False, last_byte_t, True)

    def close(self):
        try:
            self.write(b"\x03")           # Ctrl-C clears partial input.
            self.write(b"exit\n")
        except OSError:
            pass
        end = time.monotonic() + 1.0
        while time.monotonic() < end:
            try:
                pid, _ = os.waitpid(self.pid, os.WNOHANG)
                if pid:
                    break
            except ChildProcessError:
                break
            time.sleep(0.01)
        try:
            os.kill(self.pid, signal.SIGKILL)
            os.waitpid(self.pid, 0)
        except (ProcessLookupError, ChildProcessError):
            pass
        try:
            os.close(self.fd)
        except OSError:
            pass


def _drain(p, quiet_s=0.012, cap_s=0.04):
    p.pump_until(lambda _b: False, timeout_s=cap_s, quiesce_s=quiet_s)


def _keystroke_lag(p, c, timeout_s):
    _drain(p)
    since = len(strip_ansi(bytes(p.buf)))
    t = time.monotonic()
    p.write(c)
    matched, t_echo, _q = p.pump_until(
        lambda s, c=c, since=since: c in s[since:],
        timeout_s=timeout_s, quiesce_s=None,
    )
    p.write(b"\x7f")          # Backspace restores the input line.
    _drain(p)
    return (t_echo - t) * 1000.0 if matched else None


def measure_spawn_metrics(args, env) -> dict:
    regex = re.compile(args.prompt_regex.encode()) if args.prompt_regex else None
    quiesce_s = args.quiesce_ms / 1000.0
    timeout_s = args.timeout_ms / 1000.0

    out = {
        "first_prompt_lag_ms": [],
        "command_lag_ms": [],
        "input_lag_ms": [],
        "input_lag_longbuf_ms": [],
    }

    for _ in range(args.prompt_runs):
        p = Pty(_argv(args), env, args.cols, args.rows,
                raw=not args.no_raw).spawn()
        try:
            def first_pred(stripped):
                return regex.search(stripped) is not None if regex else False

            matched, t_event, quiesced = p.pump_until(
                first_pred, timeout_s=timeout_s, quiesce_s=quiesce_s
            )
            if not matched and not quiesced:
                continue
            out["first_prompt_lag_ms"].append((t_event - p.t0) * 1000.0)

            # Measure the full prompt, not its first character.
            # t_ready is the time of the last byte before the quiet period.
            for _i in range(args.inner_iters):
                _drain(p, quiet_s=0.05, cap_s=1.0)
                t_send = time.monotonic()
                p.write(b"\r")
                _m, t_ready, quiesced = p.pump_until(
                    lambda _b: False, timeout_s=timeout_s, quiesce_s=quiesce_s
                )
                out["command_lag_ms"].append(
                    (t_ready - t_send) * 1000.0 if quiesced else None)

            charset = b"abcdefghijklmnopqrstuvwxyz"
            for i in range(args.inner_iters):
                c = charset[i % len(charset):i % len(charset) + 1]
                out["input_lag_ms"].append(_keystroke_lag(p, c, timeout_s))

            # Fish updates syntax colours for the full buffer on each keypress.
            p.write(b"echo " + b"x" * args.longbuf_len)
            _drain(p)
            for i in range(args.inner_iters):
                c = charset[i % len(charset):i % len(charset) + 1]
                out["input_lag_longbuf_ms"].append(
                    _keystroke_lag(p, c, timeout_s))
            p.write(b"\x15")             # Ctrl-U clears the long input line.
        finally:
            p.close()

    return out


def measure_first_command(args, env) -> list:
    """Measure command latency from process startup, before the first prompt.

    The environment supplies the marker so echoed input cannot match command output.
    """
    timeout_s = args.timeout_ms / 1000.0
    samples = []
    for _ in range(args.prompt_runs):
        mark = secrets.token_hex(8)
        cenv = dict(env)
        cenv["BPROBE_MARK"] = mark
        p = Pty(_argv(args), cenv, args.cols, args.rows,
                raw=not args.no_raw).spawn()
        try:
            # The shell buffers this input until its line editor is ready.
            p.write(b'printf "%s\\n" "$BPROBE_MARK"\r')
            needle = mark.encode()

            def saw_mark(stripped):
                # Echoed input contains $BPROBE_MARK, not its value.
                return needle in stripped

            matched, t_event, _q = p.pump_until(
                saw_mark, timeout_s=timeout_s, quiesce_s=None
            )
            if matched:
                samples.append((t_event - p.t0) * 1000.0)
        finally:
            p.close()
    return samples


def measure_exit_time(args, env) -> list:
    """Measure elapsed time for `shell -i -c exit`, not interactive readiness."""
    import subprocess

    argv = [args.shell] + (["-l"] if args.login else []) + ["-i", "-c", "exit"]
    samples = []
    for _ in range(args.prompt_runs):
        t = time.monotonic()
        try:
            subprocess.run(argv, env=env, stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=args.timeout_ms / 1000.0)
        except subprocess.TimeoutExpired:
            continue
        samples.append((time.monotonic() - t) * 1000.0)
    return samples


def collect(args, env, skip) -> dict:
    samples = {}
    if "spawn" not in skip:
        samples.update(measure_spawn_metrics(args, env))
    if "first_command" not in skip:
        samples["first_command_lag_ms"] = measure_first_command(args, env)
    if "exit" not in skip:
        samples["exit_time_ms"] = measure_exit_time(args, env)
    return samples


def _argv(args):
    argv = [args.shell]
    if args.login:
        argv.append("-l")
    if not args.no_interactive:
        argv.append("-i")
    argv += args.shell_arg
    return argv


def build_env(args) -> dict:
    env = {} if args.clearenv else dict(os.environ)
    for kv in args.setenv:
        k, _, v = kv.partition("=")
        env[k] = v
    for k in args.unsetenv:
        env.pop(k, None)
    return env


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--shell", required=True, help="shell binary under test")
    ap.add_argument("--shell-arg", action="append", default=[],
                    help="extra arg passed to the shell (repeatable)")
    ap.add_argument("--login", action="store_true", help="login shell (-l)")
    ap.add_argument("--no-interactive", action="store_true",
                    help="do not pass -i (default passes it)")
    ap.add_argument("--cols", type=int, default=120)
    ap.add_argument("--rows", type=int, default=30)
    ap.add_argument("--prompt-regex", default=None,
                    help="bytes-regex marking the prompt tail (else quiescence)")
    ap.add_argument("--quiesce-ms", type=float, default=120.0)
    ap.add_argument("--no-raw", action="store_true",
                    help="keep the pty's termios sane (ECHO on): required for "
                         "readline shells, which suppress their own echo when "
                         "ECHO is off at startup")
    ap.add_argument("--timeout-ms", type=float, default=10000.0)
    ap.add_argument("--prompt-runs", type=int, default=10,
                    help="cold spawns for first_prompt/first_command/exit")
    ap.add_argument("--inner-iters", type=int, default=30,
                    help="iterations for command_lag/input_lag within one spawn")
    ap.add_argument("--longbuf-len", type=int, default=200)
    ap.add_argument("--label", default="")
    ap.add_argument("--mode", default="")
    ap.add_argument("--spawn-mode", default="")
    ap.add_argument("--setenv", action="append", default=[])
    ap.add_argument("--unsetenv", action="append", default=[])
    ap.add_argument("--clearenv", action="store_true")
    ap.add_argument("--skip", default="",
                    help="comma list of metric groups to skip: "
                         "spawn,first_command,exit")
    args = ap.parse_args()

    env = build_env(args)
    skip = set(s.strip() for s in args.skip.split(",") if s.strip())

    result = {
        "label": args.label,
        "mode": args.mode,
        "spawn_mode": args.spawn_mode,
        "shell": args.shell,
        "argv": _argv(args),
        "winsize": {"cols": args.cols, "rows": args.rows},
        "params": {
            "prompt_runs": args.prompt_runs,
            "inner_iters": args.inner_iters,
            "quiesce_ms": args.quiesce_ms,
            "longbuf_len": args.longbuf_len,
            "prompt_regex": args.prompt_regex,
        },
        "samples": {},
    }

    result["samples"] = collect(args, env, skip)

    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
