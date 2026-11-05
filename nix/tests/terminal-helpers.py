"""Run against a real Niri session: python3 terminal-helpers.py /path/to/manifest.json.

The manifest supplies launch, appId, execute, executeWithAppId, capture, journal,
git, nvim and path from the selected host packages. No activation is needed.
"""

from contextlib import contextmanager
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time


@contextmanager
def running(argv, env, cwd):
    process = subprocess.Popen(
        argv, env=env, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, start_new_session=True,
    )
    try:
        yield process
    finally:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate(timeout=5)


def wait_for(predicate, process):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            stdout, stderr = process.communicate()
            raise AssertionError(
                f"exited before release: {process.returncode}\n{stdout}\n{stderr}"
            )
        value = predicate()
        if value:
            return value
        time.sleep(0.025)
    raise AssertionError("timed out waiting for the real terminal/editor")


def window(pid):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(5)
        connection.connect(os.environ["NIRI_SOCKET"])
        connection.sendall(b'"Windows"\n')
        with connection.makefile() as stream:
            windows = json.loads(stream.readline())["Ok"]["Windows"]
    return next((item for item in windows if item["pid"] == pid), None)


def terminal_window(pid):
    while pid > 1:
        visible = window(pid)
        if visible:
            return visible
        stat = Path(f"/proc/{pid}/stat").read_text()
        pid = int(stat.rsplit(") ", 1)[1].split()[1])
    return None


def run(manifest):
    with tempfile.TemporaryDirectory(prefix="terminal-helpers-") as temporary:
        root = Path(temporary)
        home = root / "home with spaces"
        notes = home / "Documents/Notes"
        notebook = notes / "Contents"
        for directory in (
            home, notebook / ".zk/templates", notebook / "Inbox", notebook / "Journal",
            root / "config", root / "cache", root / "data", root / "state",
            root / "runtime", root / "editor temporary files",
        ):
            directory.mkdir(parents=True, exist_ok=True)
        (root / "runtime").chmod(0o700)
        display = Path(os.environ["WAYLAND_DISPLAY"])
        if not display.is_absolute():
            display = Path(os.environ["XDG_RUNTIME_DIR"]) / display
        env = {
            "PATH": manifest["path"], "HOME": str(home),
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_CACHE_HOME": str(root / "cache"),
            "XDG_DATA_HOME": str(root / "data"),
            "XDG_STATE_HOME": str(root / "state"),
            "XDG_RUNTIME_DIR": str(root / "runtime"),
            "WAYLAND_DISPLAY": str(display), "NIRI_SOCKET": os.environ["NIRI_SOCKET"],
            "DBUS_SESSION_BUS_ADDRESS": f"unix:path={root}/no-session-bus",
            "TMPDIR": str(root / "editor temporary files"),
            "ZK_NOTEBOOK_DIR": str(notebook), "LANG": "C.UTF-8", "TZ": "UTC",
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_ALLOW_PROTOCOL": "file", "NVIM_LOG_FILE": str(root / "cache/nvim.log"),
        }

        def command(argv):
            result = subprocess.run(
                argv, env=env, cwd=home, capture_output=True, text=True, timeout=30,
            )
            assert result.returncode == 0, (argv, result.returncode, result.stdout, result.stderr)
            return result.stdout.strip()

        def git(*args):
            return command([manifest["git"], "-C", str(notes), *args])

        def snapshot():
            return {
                str(path.relative_to(notebook)): path.read_bytes()
                for directory in (notebook / "Inbox", notebook / "Journal")
                for path in directory.rglob("*.md")
            }

        remote = root / "remote.git"
        command([manifest["git"], "init", "--bare", "--initial-branch=main", str(remote)])
        git("init", "--initial-branch=main")
        for key, value in (
            ("user.name", "Terminal smoke"), ("user.email", "terminal-smoke@invalid"),
            ("commit.gpgsign", "false"), ("push.gpgsign", "false"), ("pull.rebase", "false"),
        ):
            git("config", key, value)
        (notes / ".gitignore").write_text("Contents/.zk/notebook.db*\n")
        (notebook / ".zk/config.toml").write_text(
            '[note]\nfilename = "capture"\nextension = "md"\ntemplate = "capture.md"\n'
            '[group.inbox]\npaths = ["Inbox"]\n'
            '[group.journal]\npaths = ["Journal"]\n'
            '[group.journal.note]\nfilename = "journal"\ntemplate = "journal.md"\n'
            f'[tool]\neditor = "{manifest["nvim"]} --headless"\n'
        )
        (notebook / ".zk/templates/capture.md").write_text("# {{title}}\n\n{{content}}\n")
        (notebook / ".zk/templates/journal.md").write_text("# Journal\n")
        git("add", ".")
        git("commit", "-m", "Disposable notebook")
        git("remote", "add", "origin", str(remote))
        git("push", "--set-upstream", "origin", "main")
        initial_commit = git("rev-parse", "HEAD")

        with running(manifest["launch"], env, home) as process:
            visible = wait_for(lambda: window(process.pid), process)
            assert visible["app_id"] == manifest["appId"], visible
        print("PASS launch: real configured Foot opens with the selected app ID")

        child = root / "argv-child.py"
        child.write_text(
            "import json, os\nfrom pathlib import Path\nimport sys, time\n"
            "control = Path(os.environ['TERMINAL_SMOKE_CONTROL'])\n"
            "(control / 'ready.new').write_text(json.dumps({'argv': sys.argv[1:], 'pid': os.getppid()}))\n"
            "(control / 'ready.new').replace(control / 'ready')\n"
            "while not (control / 'release').exists(): time.sleep(0.025)\n"
            "sys.exit(37)\n"
        )
        arguments = ["", "two words", "; $(touch should-not-exist)", "'\"\\`", "*?[abc]", "--flag", "line1\nline2"]
        for operation, app_id in (
            ("execute", manifest["appId"]),
            ("executeWithAppId", "foot.smoke space;$(false)"),
        ):
            control = root / operation
            control.mkdir()
            argv = manifest[operation] + ([app_id] if operation == "executeWithAppId" else [])
            with running(
                argv + [sys.executable, str(child), *arguments],
                env | {"TERMINAL_SMOKE_CONTROL": str(control)}, home,
            ) as process:
                wait_for(lambda: (control / "ready").exists(), process)
                observed = json.loads((control / "ready").read_text())
                assert observed["argv"] == arguments, observed
                visible = wait_for(lambda: window(observed["pid"]), process)
                assert visible["app_id"] == app_id, visible
                assert process.poll() is None
                (control / "release").touch()
                stdout, stderr = process.communicate(timeout=30)
                assert process.returncode == 37, (process.returncode, stdout, stderr)
            assert not (home / "should-not-exist").exists()
            print(f"PASS {operation}: exact argv, runtime app ID, waiting and child exit 37")

        automation = root / "editor.vim"
        automation.write_text(
            "set noswapfile noundofile shadafile=NONE\n"
            "let s:control = $TERMINAL_SMOKE_CONTROL\n"
            "if stridx(expand('%:p'), $TMPDIR . '/') == 0\n"
            "  call writefile([json_encode({'capture': expand('%:p'), 'sentinel': $ZK_CAPTURE_SENTINEL, 'pid': getpid()})], s:control . '/ready.new')\n"
            "  call rename(s:control . '/ready.new', s:control . '/ready')\n"
            "  while !filereadable(s:control . '/release')\n"
            "    sleep 20m\n"
            "  endwhile\n"
            "  let s:action = readfile(s:control . '/release')[0]\n"
            "  if s:action ==# 'save'\n"
            "    call setline(1, readfile(s:control . '/input'))\n"
            "    write\n"
            "    qall\n"
            "  elseif s:action ==# 'error'\n"
            "    cquit 43\n"
            "  else\n"
            "    qall!\n"
            "  endif\n"
            "else\n"
            "  qall!\n"
            "endif\n"
        )
        env |= {
            "TERMINAL_SMOKE_VIM": str(automation),
            "VIMINIT": "autocmd VimEnter * ++nested execute 'source ' . fnameescape($TERMINAL_SMOKE_VIM)",
        }

        def helper(name, label, action, content):
            control = root / label
            control.mkdir()
            (control / "input").write_text(content)
            before = snapshot()
            commit = git("rev-parse", "HEAD")
            app_id = "foot.capture" if name == "capture" else "foot.journal smoke;$(false)"
            helper_env = env | {
                "TERMINAL_SMOKE_CONTROL": str(control), "FOOT_JOURNAL_APP_ID": app_id,
            }
            with running([manifest[name]], helper_env, home) as process:
                wait_for(lambda: (control / "ready").exists(), process)
                observed = json.loads((control / "ready").read_text())
                capture = Path(observed["capture"])
                sentinel = Path(observed["sentinel"])
                assert capture.parent == Path(env["TMPDIR"]), observed
                assert sentinel.parent == Path(env["TMPDIR"]), observed
                assert capture.exists() and not sentinel.exists(), observed
                visible = wait_for(lambda: terminal_window(observed["pid"]), process)
                assert visible["app_id"] == app_id, visible
                assert snapshot() == before and git("rev-parse", "HEAD") == commit
                assert process.poll() is None and capture.exists()
                (control / "release").write_text(action + "\n")
                stdout, stderr = process.communicate(timeout=30)
                assert process.returncode == 0, (label, process.returncode, stdout, stderr)
                assert not capture.exists() and not sentinel.exists(), observed
            if action != "save":
                assert snapshot() == before and git("rev-parse", "HEAD") == commit
            print(f"PASS {label}: real Foot/nvim, no early completion, temporary-file cleanup, status 0")
            return stdout

        title = "Capture title with spaces ; $(false)"
        body = "first line ; $(false)\n\n  indented body with spaces\nlast line * ?"
        helper("capture", "capture-save", "save", f"% title:  {title}  \n\n \t\n{body}\n \t\n")
        capture_path = notebook / "Inbox/capture.md"
        assert capture_path.read_text() == f"# {title}\n\n{body}\n"
        assert git("rev-list", "--count", f"{initial_commit}..HEAD") == "1"
        assert git("rev-parse", "HEAD") == command([
            manifest["git"], "--git-dir", str(remote), "rev-parse", "main",
        ])
        print("PASS capture data: exact title/body, one commit, local bare remote updated")

        journal_path = notebook / "Journal/journal.md"
        expected = "# Journal\n"
        for number in (1, 2):
            entry = f"journal entry {number} ; $(false)\n\n  indented journal body"
            stdout = helper("journal", f"journal-save-{number}", "save", entry + "\n")
            expected += "\n" + entry + "\n"
            assert journal_path.read_text() == expected
            assert list((notebook / "Journal").glob("*.md")) == [journal_path]
            assert stdout.strip() == str(journal_path), stdout
        print("PASS journal data: real zk creates one note, each invocation appends exactly once")

        for name in ("capture", "journal"):
            for action in ("cancel", "error"):
                helper(name, f"{name}-{action}", action, "must not be saved\n")
        assert not list(Path(env["TMPDIR"]).iterdir())
        print("PASS cancellation/error: note data and commits preserved; inherited nonzero-to-zero policy retained")


if __name__ == "__main__":
    run(json.loads(Path(sys.argv[1]).read_text()))
