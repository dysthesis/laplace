{
  pkgs,
  lib,
}: let
  title = "can't \"quote\" \\path $HOME ; {cmd}";
  fuzzel = import ../../user/wrapped/fuzzel {
    inherit pkgs lib;
    config.laplace.display.fuzzel.fontSize = 11;
    terminal.launch = [(lib.getExe pkgs.foot) "--title=${title}" "--app-id=laplace.fuzzel"];
  };
in
  pkgs.runCommand "fuzzel-terminal-check" {
    nativeBuildInputs = [pkgs.python3 pkgs.sway-unwrapped];
    FONTCONFIG_FILE = pkgs.makeFontsConf {fontDirectories = [pkgs.dejavu_fonts];};
  } ''
    export HOME="$TMPDIR/home" XDG_RUNTIME_DIR="$TMPDIR/runtime"
    export XDG_CONFIG_HOME="$TMPDIR/config" XDG_CACHE_HOME="$TMPDIR/cache"
    export XDG_DATA_HOME="$TMPDIR/data" XDG_DATA_DIRS="$TMPDIR/data-dirs"
    export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
    unset DISPLAY WAYLAND_DISPLAY SWAYSOCK
    mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME/applications" "$XDG_DATA_DIRS"
    chmod 700 "$XDG_RUNTIME_DIR"
    cat > "$XDG_DATA_HOME/applications/laplace.desktop" <<EOF
    [Desktop Entry]
    Type=Application
    Name=LaplaceFuzzelTerminal
    Exec=${lib.getExe' pkgs.coreutils "sleep"} 60
    Terminal=true
    EOF
    printf 'output * mode 800x600\n' > "$TMPDIR/sway.conf"
    python3 - ${lib.escapeShellArg (lib.getExe fuzzel)} ${lib.escapeShellArg title} <<'PY'
    import json
    import os
    from pathlib import Path
    import signal
    import subprocess
    import sys
    import time

    def wait_for(predicate, process):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise AssertionError(f"process exited with status {process.returncode}")
            value = predicate()
            if value:
                return value
            time.sleep(0.05)
        raise AssertionError("timed out waiting for the terminal window")

    def windows(node):
        yield node
        for child in node.get("nodes", []) + node.get("floating_nodes", []):
            yield from windows(child)

    with open("sway.log", "w+") as log:
        sway = subprocess.Popen(["sway", "-c", os.environ["TMPDIR"] + "/sway.conf"], stdout=log, stderr=log, start_new_session=True)
        launcher = None
        try:
            runtime = Path(os.environ["XDG_RUNTIME_DIR"])
            display = wait_for(lambda: next((p for p in runtime.glob("wayland-*") if p.is_socket()), None), sway)
            os.environ["WAYLAND_DISPLAY"] = display.name
            socket = runtime / f"sway-ipc.{os.getuid()}.{sway.pid}.sock"
            wait_for(socket.exists, sway)
            launcher = subprocess.Popen([sys.argv[1], "--search=LaplaceFuzzelTerminal", "--auto-select", "--match-mode=exact", "--no-icons", "--log-no-syslog"], stdout=log, stderr=log, start_new_session=True)
            assert launcher.wait(timeout=20) == 0

            def terminal():
                tree = json.loads(subprocess.check_output(["swaymsg", "-s", str(socket), "-t", "get_tree"]))
                return next((node for node in windows(tree) if node.get("app_id") == "laplace.fuzzel"), None)

            window = wait_for(terminal, sway)
            assert window["name"] == sys.argv[2], window
            print("PASS: Fuzzel launched real Foot with the exact literal terminal title")
        finally:
            for process in (launcher, sway):
                if process is not None:
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
            log.seek(0)
            print(log.read())
    PY
    touch "$out"
  ''
