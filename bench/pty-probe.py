#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# pty-probe.py - interactive-shell latency probe over a pseudo-terminal.
#
# zsh-bench (https://github.com/romkatv/zsh-bench) is the reference for *what*
# to measure, but it only drives zsh. This re-implements its four perceptual
# metrics for an ARBITRARY shell binary (fish, bash, ...) by doing what
# zsh-bench does: allocate a PTY, exec the shell in it, inject keystrokes, and
# timestamp the shell's reactions.
#
#   first_prompt_lag   spawn -> first prompt fully painted
#   first_command_lag  spawn -> first interactive command starts executing
#   command_lag        Enter on an empty line -> next prompt painted
#   input_lag          one keypress -> that character echoed on the line
#   input_lag_longbuf  same, but with a long line already typed (stresses the
#                      per-keystroke full-buffer re-highlight that fish does)
#
# Stdlib only. Emits raw per-sample measurements as JSON on stdout; aggregation
# and statistics live in stats.py so the raw data can be re-analysed later.
#
# Heuristics (documented because they are the load-bearing approximations):
#   * "prompt is ready" = output has arrived and then gone quiet for
#     --quiesce-ms, OR an optional --prompt-regex matched. Quiescence is robust
#     across prompts; the regex is a tighter confirmation when you know the
#     prompt's tail (e.g. starship's character module).
#   * first_command uses a random sentinel passed via the environment so the
#     *typed* command text ($BPROBE_MARK) differs from the *executed* output
#     (the random value), making the two unambiguous in the byte stream.
# ---------------------------------------------------------------------------
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

# rich is optional: live progress bars when present, silent fallback otherwise.
try:
    __import__("rich")
    _RICH = True
except Exception:  # pragma: no cover - rich absent
    _RICH = False

# CSI / OSC / lone control-byte stripper, so matching ignores colour + cursor
# moves that prompts emit. Kept deliberately broad.
_ANSI = re.compile(
    rb"\x1b\[[0-9;?]*[ -/]*[@-~]"      # CSI ... final
    rb"|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)"  # OSC ... BEL/ST
    rb"|\x1b[@-Z\\-_]"                 # 2-byte escapes
    rb"|[\x00-\x08\x0e-\x1f]"          # stray control bytes (keep \t,\n,\r)
)


def strip_ansi(b: bytes) -> bytes:
    return _ANSI.sub(b"", b)


# Terminal capability/status queries that fish and starship emit at startup and
# then BLOCK on, reading stdin for the reply. A dumb PTY has no emulator on the
# far end, so without canned answers the shell consumes our keystrokes as the
# (malformed) reply and never reaches its line editor. We answer like a minimal
# real terminal would. (DA1/DA2, CPR/DSR, OSC 10/11 colour, XTVERSION,
# XTGETTCAP, kitty keyboard flags.)
_QUERY = re.compile(
    rb"\x1b\[(?:0)?c"                       # DA1
    rb"|\x1b\[>(?:0)?c"                     # DA2
    rb"|\x1b\[6n"                           # CPR (cursor position)
    rb"|\x1b\[5n"                           # DSR (device status)
    rb"|\x1b\]1[01];\?(?:\x07|\x1b\\)"      # OSC 10/11 fg/bg colour query
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
        digits = q[2:4]                            # b"10" (fg) or b"11" (bg)
        rgb = b"ffff/ffff/ffff" if digits == b"10" else b"0000/0000/0000"
        return b"\x1b]" + digits + b";rgb:" + rgb + b"\x07"
    if q.endswith(b"6n"):
        return b"\x1b[1;1R"                         # cursor at row 1, col 1
    if q.endswith(b"5n"):
        return b"\x1b[0n"                           # terminal OK
    if q.startswith(b"\x1b[>") and q.endswith(b"c"):
        return b"\x1b[>0;10;1c"                     # DA2
    if q.endswith(b"c"):
        return b"\x1b[?1;2c"                        # DA1 (VT100 w/ AVO)
    return b""


class Pty:
    """A shell running in a pseudo-terminal we can read from and type into."""

    def __init__(self, argv, env, cols, rows, raw=True):
        self.argv = argv
        self.env = env
        self.cols = cols
        self.rows = rows
        self.raw = raw
        self.pid = -1
        self.fd = -1
        self.buf = bytearray()           # everything read so far (raw)
        self.t0 = 0.0                    # monotonic time at exec
        self._qpos = 0                   # scan cursor for terminal queries

    def spawn(self):
        self.t0 = time.monotonic()
        pid, fd = pty.fork()
        if pid == 0:
            # Child: this process IS the controlling-tty session leader.
            try:
                os.execvpe(self.argv[0], self.argv, self.env)
            except Exception as exc:  # pragma: no cover - child path
                os.write(2, f"exec failed: {exc}\n".encode())
                os._exit(127)
        self.pid = pid
        self.fd = fd
        # Fix the window size deterministically (prompt width depends on it).
        winsz = struct.pack("HHHH", self.rows, self.cols, 0, 0)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, winsz)
        # Raw mode: kill kernel echo/canonical processing so we time the SHELL's
        # rendered echo (syntax highlight, autosuggest), not the instant kernel
        # echo that races it before the line editor takes over. Caveat:
        # readline samples the termios ECHO flag at startup and suppresses its
        # own rendered echo when it is off, so for readline shells (bash) raw
        # mode must stay off (--no-raw) or every keystroke probe times out.
        if self.raw:
            try:
                tty.setraw(self.fd)
            except termios.error:
                pass
        # Non-blocking reads for the select() loop.
        flags = fcntl.fcntl(self.fd, fcntl.F_GETFL)
        fcntl.fcntl(self.fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
        return self

    # -- low level ---------------------------------------------------------
    def _read_some(self) -> bytes:
        try:
            chunk = os.read(self.fd, 65536)
        except (BlockingIOError, InterruptedError):
            return b""
        except OSError:
            return b""           # child gone / fd closed
        if chunk:
            self.buf += chunk
        return chunk

    def _answer_queries(self):
        """Reply to any terminal queries in the newly-read bytes, like a real
        emulator would, so the shell stops blocking and accepts keystrokes."""
        region = bytes(self.buf[self._qpos:])
        matches = list(_QUERY.finditer(region))
        if not matches:
            # Keep a short tail so a query split across reads is still caught.
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
        """Read until predicate(stripped_buf) is true, or until output has been
        quiet for quiesce_s after at least one byte, or until timeout.

        Returns (matched: bool, t_event: float, quiesced: bool).
        t_event is the monotonic time of the byte that satisfied the condition
        (for quiescence, the last byte before the gap)."""
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
                # EOF
                return (False, last_byte_t or t, False)
            # select timed out: either overall timeout or a quiescence gap
            if (
                quiesce_s is not None
                and last_byte_t is not None
                and (time.monotonic() - last_byte_t) >= quiesce_s
                and len(self.buf) > start_len
            ):
                return (False, last_byte_t, True)
            # else keep waiting for the overall deadline

    def close(self):
        try:
            self.write(b"\x03")           # Ctrl-C, abandon any partial line
            self.write(b"exit\n")
        except OSError:
            pass
        # Give it a moment, then make sure it is gone.
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


def prompt_predicate(regex: re.Pattern | None):
    """A predicate that never matches when no regex is given (so the caller
    falls back to quiescence)."""
    if regex is None:
        return lambda _b: False
    return lambda b: regex.search(b) is not None


def wait_prompt(p: Pty, since_len, regex, quiesce_s, timeout_s):
    """Wait for the next prompt to be 'ready' relative to whatever is already
    in the buffer. Returns the monotonic time the prompt was ready."""
    # Predicate matches the regex only in the *newly arrived* tail.
    def pred(stripped):
        if regex is None:
            return False
        return regex.search(stripped[since_len:]) is not None

    matched, t_event, _q = p.pump_until(
        pred, timeout_s=timeout_s, quiesce_s=quiesce_s
    )
    return t_event


def _drain(p, quiet_s=0.012, cap_s=0.04):
    """Read until output has been quiet for quiet_s, so a subsequent timing
    starts from a settled screen (no pending render racing the measurement)."""
    p.pump_until(lambda _b: False, timeout_s=cap_s, quiesce_s=quiet_s)


def _keystroke_lag(p, c, timeout_s):
    """One keypress -> the shell's rendered echo of it. Settles first so the
    echo we time is genuinely new output, then backspaces to restore the line."""
    _drain(p)
    since = len(strip_ansi(bytes(p.buf)))
    t = time.monotonic()
    p.write(c)
    _m, t_echo, _q = p.pump_until(
        lambda s, c=c, since=since: c in s[since:],
        timeout_s=timeout_s, quiesce_s=None,
    )
    p.write(b"\x7f")          # backspace: undo the char, keep line state stable
    _drain(p)
    return (t_echo - t) * 1000.0


def measure_spawn_metrics(args, env, step=None) -> dict:
    """Spawn A: first_prompt, then steady-state command_lag and input_lag."""
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
            # ---- first_prompt --------------------------------------------
            def first_pred(stripped):
                return regex.search(stripped) is not None if regex else False

            matched, t_event, quiesced = p.pump_until(
                first_pred, timeout_s=timeout_s, quiesce_s=quiesce_s
            )
            if not matched and not quiesced:
                # Never settled; record nothing for this spawn but keep going.
                continue
            out["first_prompt_lag_ms"].append((t_event - p.t0) * 1000.0)

            # ---- command_lag: Enter on an empty line ---------------------
            # Measure send -> the redraw settling (full prompt painted), not the
            # first prompt glyph, so the cheap transient-prompt char doesn't
            # mask starship's real per-Enter render cost. The render arrives in
            # bursts (transient repaint, clear, full prompt) whose internal
            # gaps reach ~90 ms here, so the quiesce window must comfortably
            # exceed them or the sample randomly clocks an intermediate burst.
            # Use the same window as first_prompt; t_ready is the last byte's
            # time, so the wait itself does not inflate the number.
            for _i in range(args.inner_iters):
                _drain(p, quiet_s=0.05, cap_s=1.0)
                t_send = time.monotonic()
                p.write(b"\r")
                _m, t_ready, _q = p.pump_until(
                    lambda _b: False, timeout_s=timeout_s, quiesce_s=quiesce_s
                )
                out["command_lag_ms"].append((t_ready - t_send) * 1000.0)

            # ---- input_lag: single keypress echo -------------------------
            charset = b"abcdefghijklmnopqrstuvwxyz"
            for i in range(args.inner_iters):
                c = charset[i % len(charset):i % len(charset) + 1]
                out["input_lag_ms"].append(_keystroke_lag(p, c, timeout_s))

            # ---- input_lag_longbuf: echo under a long, highlighted line --
            # fish re-highlights the whole buffer per keystroke; a long line is
            # the worst case the second write-up warns about.
            p.write(b"echo " + b"x" * args.longbuf_len)
            _drain(p)
            for i in range(args.inner_iters):
                c = charset[i % len(charset):i % len(charset) + 1]
                out["input_lag_longbuf_ms"].append(
                    _keystroke_lag(p, c, timeout_s))
            p.write(b"\x15")             # Ctrl-U, clear the long line
        finally:
            p.close()
            if step:
                step()

    return out


def measure_first_command(args, env, step=None) -> list:
    """Spawn B: from a cold spawn, type a command immediately and time until it
    *executes* (its sentinel output appears). The sentinel comes from the env
    so the typed text and the executed output never collide."""
    timeout_s = args.timeout_ms / 1000.0
    samples = []
    for _ in range(args.prompt_runs):
        mark = secrets.token_hex(8)
        cenv = dict(env)
        cenv["BPROBE_MARK"] = mark
        p = Pty(_argv(args), cenv, args.cols, args.rows,
                raw=not args.no_raw).spawn()
        try:
            # Type immediately; the shell buffers until its line editor is up,
            # so the time until the sentinel prints is first_command_lag.
            p.write(b'printf "%s\\n" "$BPROBE_MARK"\r')
            needle = mark.encode()

            def saw_mark(stripped):
                # The executed output is the bare value on its own; the echoed
                # command line contains the literal $BPROBE_MARK, not the value.
                return needle in stripped

            matched, t_event, _q = p.pump_until(
                saw_mark, timeout_s=timeout_s, quiesce_s=None
            )
            if matched:
                samples.append((t_event - p.t0) * 1000.0)
        finally:
            p.close()
            if step:
                step()
    return samples


def measure_exit_time(args, env, step=None) -> list:
    """The 'wrong' coarse metric, kept only as a labelled floor: how long a
    non-interactive `shell -i -c exit` takes, wall-clock, no PTY."""
    import subprocess

    argv = [args.shell] + (["-l"] if args.login else []) + ["-i", "-c", "exit"]
    samples = []
    for _ in range(args.prompt_runs):
        t = time.monotonic()
        subprocess.run(argv, env=env, stdin=subprocess.DEVNULL,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        samples.append((time.monotonic() - t) * 1000.0)
        if step:
            step()
    return samples


def collect(args, env, skip) -> dict:
    """Run the requested metric groups, with a live rich progress bar (to
    stderr, so stdout stays pure JSON) when rich is available and stderr is a
    terminal. Falls back to running them silently otherwise."""
    samples = {}

    def run_groups(stepper):
        if "spawn" not in skip:
            samples.update(measure_spawn_metrics(args, env, stepper("spawn")))
        if "first_command" not in skip:
            samples["first_command_lag_ms"] = \
                measure_first_command(args, env, stepper("first_command"))
        if "exit" not in skip:
            samples["exit_time_ms"] = \
                measure_exit_time(args, env, stepper("exit"))

    labels = {
        "spawn": "first_prompt + command/input lag",
        "first_command": "first_command_lag",
        "exit": "exit_time (floor)",
    }
    if _RICH and sys.stderr.isatty():
        from rich.console import Console
        from rich.progress import (
            BarColumn,
            MofNCompleteColumn,
            Progress,
            SpinnerColumn,
            TextColumn,
            TimeElapsedColumn,
            TimeRemainingColumn,
        )
        con = Console(stderr=True)
        title = args.label or args.shell.rsplit("/", 1)[-1]
        con.rule(f"[bold cyan]probe[/] {title}  "
                 f"[dim]{args.mode}/{args.spawn_mode}[/]")
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            MofNCompleteColumn(),
            TimeElapsedColumn(),
            TimeRemainingColumn(),
            console=con,
            transient=False,
        ) as prog:
            tasks = {}

            def stepper(group):
                if group in skip:
                    return None
                tid = prog.add_task(labels[group], total=args.prompt_runs)
                tasks[group] = tid
                return lambda: prog.advance(tid)

            run_groups(stepper)
    else:
        run_groups(lambda _g: None)
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
