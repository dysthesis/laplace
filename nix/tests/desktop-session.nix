{
  pkgs,
  lib,
  inputs,
  nixosConfigurations,
}: let
  desktopPkgs = nixosConfigurations.phobos.pkgs;
  ocr = pkgs.tesseract.override {enableLanguages = ["eng"];};
in
  pkgs.testers.runNixOSTest {
    name = "desktop-session";
    extraPythonPackages = ps: [ps.vncdo];
    requiredFeatures.opengl = true;
    qemu.package = desktopPkgs.qemu_kvm;
    node.pkgs = lib.mkForce desktopPkgs;
    node.specialArgs = {inherit inputs lib;};

    nodes.machine = {config, ...}: let
      loginShell = desktopPkgs.unstable.callPackage ../../user/wrapped/bash {
        inherit config lib;
        pkgs = desktopPkgs;
      };
      pamEnvironment = config.security.pam.services.login.rules.session.env;
    in {
      imports = [
        ../../system/display
        ../../user/gtk
        ../../modules/ariadne
      ];
      options.laplace.profiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["desktop"];
      };
      # The VM must not read the workstation's unrelated calendar credential.
      options.sops.secrets.caldav.path = lib.mkOption {
        type = lib.types.str;
        default = "/run/unavailable-caldav-password";
      };
      config = {
        laplace.desktop =
          nixosConfigurations.phobos.config.laplace.desktop
          // {bar = lib.components.waybar;};

        users.users.alice = {
          isNormalUser = true;
          uid = 1000;
          password = "desktop-smoke";
          extraGroups = ["wheel" "video" "input"];
          shell = "${loginShell}/bin/bash";
          ariadne = true;
          # Keep the manager alive so logout cannot hide broken session teardown.
          linger = true;
        };
        services.dbus.enable = true;
        services.getty.autologinUser = null;
        environment.systemPackages = with desktopPkgs; [
          glib
          polkit
          (makeDesktopItem {
            name = "laplace-session-proof";
            desktopName = "LaplaceSessionProof";
            exec = "${lib.getExe configured.foot} --app-id=laplace.launcher-proof -e ${coreutils}/bin/sleep infinity";
          })
        ];
        environment.shells =
          map (
            shell:
              if shell == nixosConfigurations.phobos.config.users.users.demiurge.shell
              then "${loginShell}/bin/bash"
              else shell
          )
          nixosConfigurations.phobos.config.environment.shells;
        fonts.packages = [desktopPkgs.atkinson-hyperlegible-next];

        # A login-only value distinguishes native environment import from boot defaults.
        security.pam.services.login.rules.session.desktop-probe = {
          order = pamEnvironment.order + 1;
          control = "required";
          modulePath = pamEnvironment.modulePath;
          settings = {
            conffile = desktopPkgs.writeText "desktop-login-environment" ''
              NIRI_LOGIN_PROBE DEFAULT=console-login OVERRIDE=console-login
            '';
            readenv = 0;
          };
        };
        virtualisation = {
          memorySize = 4096;
          cores = 2;
          qemu.options = ["-vga none -device virtio-gpu-gl-pci -display egl-headless -vnc unix:./vnc"];
        };
      };
    };

    testScript = {nodes, ...}: let
      niri = lib.getExe nodes.machine.programs.niri.package;
      terminal =
        lib.escapeShellArgs
        (nodes.machine.laplace.desktop.term.build {
          pkgs = desktopPkgs;
          inherit lib;
          foot = desktopPkgs.configured.foot;
        }).launch;
    in ''
      import csv
      import json
      import re
      import os
      import shlex
      import subprocess
      import time
      from pathlib import Path
      from typing import Any
      from vncdotool import api as vnc
      from PIL import Image

      q = shlex.quote
      units = ["niri", "niri-swallow", "noctalia", "vicinae", "polkit-gnome", "waybar"]
      session_environment: dict[str, str] = {}
      noctalia_command = ${builtins.toJSON nodes.machine.systemd.user.services.noctalia.serviceConfig.ExecStart}
      user_prefix = (
          "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 "
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
      )

      def user_command(command: str) -> str:
          return user_prefix + "/bin/sh -c " + q(command)

      def user(command: str) -> str:
          return machine.succeed(user_command(command)).strip()

      def environment() -> dict[str, str]:
          return dict(item.split("=", 1) for item in shlex.split(user("systemctl --user show-environment")))

      def niri(command: str) -> str:
          return user(f"env NIRI_SOCKET={q(session_environment['NIRI_SOCKET'])} ${niri} msg {command}")

      def ipc(command: str) -> Any:
          return json.loads(niri("--json " + command))

      def shell(command: str) -> str:
          return user(f"env WAYLAND_DISPLAY={q(session_environment['WAYLAND_DISPLAY'])} {noctalia_command} msg {command}")

      # QEMU screendump rejects GL scanouts; VNC supplies display readback.
      def screenshot(name: str) -> Path:
          image = Path(machine.out_dir) / (name + ".png")
          with vnc.connect(str(machine.state_dir / "vnc"), timeout=10) as client:
              client.captureScreen(str(image))
          return image

      def wait_for_text(pattern: str) -> None:
          def matches(_: bool) -> bool:
              image = screenshot("screen")
              enlarged = image.with_name("screen-large.png")
              with Image.open(image) as pixels:
                  pixels.resize((pixels.width * 4, pixels.height * 4)).save(enlarged)
              text = subprocess.check_output(["${lib.getExe ocr}", str(enlarged), "stdout", "--psm", "11"], text=True)
              return re.search(pattern, text) is not None
          retry(matches, timeout_seconds=60)

      def click_workspace(label: str) -> None:
          image = screenshot("waybar-workspace")
          enlarged = image.with_name("waybar-workspace-large.png")
          with Image.open(image) as pixels:
              width, height = pixels.width * 4, pixels.height * 4
              pixels.resize((width, height)).save(enlarged)
          rows = csv.DictReader(subprocess.check_output(
              ["${lib.getExe ocr}", str(enlarged), "stdout", "--psm", "11", "tsv"], text=True,
          ).splitlines(), delimiter="\t")
          button = next(row for row in rows if row["text"] == label and int(row["top"]) > height * 3 // 4)
          # OCR can merge the neighbouring pill into the word's bounding box.
          x = (int(button["left"]) + min(int(button["width"]), int(button["height"])) // 2) // 4
          y = (int(button["top"]) + int(button["height"]) // 2) // 4
          print(f"Clicking {label} at {x},{y}")
          assert machine.qmp_client is not None
          # Recalibrate away from Niri's overview hot corner after re-login.
          for px, py in ((width // 8, height // 8), (x, y)):
              events: Any = {"events": [
                  {"type": "abs", "data": {"axis": "x", "value": px * 32767 // (width // 4)}},
                  {"type": "abs", "data": {"axis": "y", "value": py * 32767 // (height // 4)}},
              ]}
              machine.qmp_client.send("input-send-event", events)
              time.sleep(0.1)
          for down in (True, False):
              button_events: Any = {"events": [{"type": "btn", "data": {"down": down, "button": "left"}}]}
              machine.qmp_client.send("input-send-event", button_events)
              time.sleep(0.1)
          screenshot("waybar-click")

      def login(tty: int) -> None:
          machine.succeed(f"chvt {tty}")
          machine.wait_until_tty_matches(str(tty), "login: ")
          machine.send_chars("alice\n")
          machine.wait_until_tty_matches(str(tty), "Password:")
          machine.send_chars("desktop-smoke\n")

      # EGL-headless needs no X server; prevent the driver's automatic -nographic.
      os.environ.setdefault("DISPLAY", "")
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("user@1000.service")
      assert "NIRI_LOGIN_PROBE" not in environment()

      with subtest("a non-VT1 login does not start the desktop"):
          login(2)
          machine.send_chars("printf tty2-ready >/tmp/tty2-ready\n")
          machine.wait_for_file("/tmp/tty2-ready")
          machine.fail(user_command("systemctl --user is-active niri.service"))
          machine.send_chars("exit\n")
          machine.wait_until_tty_matches("2", "login: ")

      previous_pids: dict[str, int] = {}
      for generation in (1, 2):
          with subtest(f"VT1 login {generation} starts the selected native session"):
              user("systemctl --user unset-environment NIRI_LOGIN_PROBE")
              login(1)
              machine.wait_until_succeeds(user_command("systemctl --user is-active niri.service"), timeout=90)
              for unit in units:
                  machine.wait_for_unit(unit + ".service", user="alice")
              machine.wait_for_unit("graphical-session.target", user="alice")
              session_environment = environment()
              retry(lambda _: any(output["current_mode"] is not None for output in ipc("outputs").values()), timeout_seconds=60)
              assert session_environment["NIRI_LOGIN_PROBE"] == "console-login"
              assert session_environment["XDG_SESSION_TYPE"] == "wayland"
              assert session_environment["XDG_CURRENT_DESKTOP"] == "niri"
              assert session_environment["WAYLAND_DISPLAY"]
              assert session_environment["NIRI_SOCKET"]
              pids = {unit: int(user(f"systemctl --user show {unit}.service -p MainPID --value")) for unit in units}
              assert all(pid > 0 for pid in pids.values())
              assert len(set(pids.values())) == len(units)
              for unit, pid in previous_pids.items():
                  assert pids[unit] != pid
              for unit in units:
                  assert user(f"systemctl --user show {unit}.service -p NRestarts --value") == "0"
              compositor_environment = dict(
                  line.split("=", 1) for line in machine.succeed(
                      f"tr '\\0' '\\n' </proc/{pids['niri']}/environ"
                  ).splitlines() if "=" in line
              )
              assert compositor_environment["NIRI_LOGIN_PROBE"] == "console-login"
              argv = machine.succeed(f"tr '\\0' '\\n' </proc/{pids['niri']}/cmdline").splitlines()
              assert argv[1:] == ["--session"], argv
              for unit in ("niri", "noctalia", "waybar"):
                  name = machine.succeed(f"cat /proc/{pids[unit]}/comm").strip()
                  assert user(f"pgrep -u alice -x {q(re.escape(name))}").splitlines() == [str(pids[unit])]

          with subtest(f"external bar and notifications belong to session {generation}"):
              retry(lambda _: any(layer["namespace"] == "waybar" for layer in ipc("layers")))
              layers = ipc("layers")
              assert sum(layer["namespace"] == "waybar" for layer in layers) == 1, layers
              assert not any(layer["namespace"].startswith("noctalia-bar") for layer in layers), layers
              assert any(layer["namespace"] == "noctalia-wallpaper" for layer in layers), layers
              machine.fail("pgrep -u alice -x 'dunst|[.]dunst-wrapped'")
              owner = json.loads(user(
                  "busctl --user --json=short call org.freedesktop.DBus /org/freedesktop/DBus "
                  "org.freedesktop.DBus GetConnectionUnixProcessID s org.freedesktop.Notifications"
              ))
              assert owner["data"] == [pids["noctalia"]], owner
              user(
                  "gdbus call --session --dest org.freedesktop.Notifications "
                  "--object-path /org/freedesktop/Notifications "
                  "--method org.freedesktop.Notifications.Notify "
                  "'Lifecycle smoke' 0 \"\" 'Native session notification' 'Disposable VM' '[]' '{}' 3000"
              )
              settings = user(
                  "gdbus call --session --dest org.freedesktop.portal.Desktop "
                  "--object-path /org/freedesktop/portal/desktop "
                  "--method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme"
              )
              assert "uint32" in settings, settings
              screenshot(f"desktop-session-{generation}")

          with subtest(f"native keyboard and selected terminal work in session {generation}"):
              machine.send_key("meta_l-ret")
              retry(lambda _: any(window["app_id"] == "foot" for window in ipc("windows")))
              machine.send_chars(f"printf keyboard-ready >/tmp/desktop-keyboard-{generation}\n")
              machine.wait_for_file(f"/tmp/desktop-keyboard-{generation}")
              machine.send_chars("exit\n")
              retry(lambda _: not any(window["app_id"] == "foot" for window in ipc("windows")))

          with subtest(f"Waybar tracks titles and changes workspace by mouse in session {generation}"):
              niri("action focus-workspace 1")
              niri("action set-workspace-name FIRST")
              # Blank clients leave the real Waybar as the only visible source of each title.
              niri("action spawn -- ${terminal} --app-id=laplace.bar-proof --title=ALPHA -e ${desktopPkgs.coreutils}/bin/sleep infinity")
              retry(lambda _: any(window["title"] == "ALPHA" for window in ipc("windows")))
              wait_for_text("ALPHA")
              machine.send_key("meta_l-2")
              retry(lambda _: any(workspace["idx"] == 2 and workspace["is_focused"] for workspace in ipc("workspaces")))
              niri("action set-workspace-name SECOND")
              niri("action spawn -- ${terminal} --app-id=laplace.bar-proof --title=BETA -e ${desktopPkgs.coreutils}/bin/sleep infinity")
              retry(lambda _: any(window["title"] == "BETA" for window in ipc("windows")))
              wait_for_text("BETA")
              wait_for_text("FIRST")
              click_workspace("FIRST")
              retry(lambda _: any(workspace["name"] == "FIRST" and workspace["is_focused"] for workspace in ipc("workspaces")), timeout_seconds=60)
              wait_for_text("ALPHA")
              screenshot(f"waybar-interaction-{generation}")
              for window in ipc("windows"):
                  if window["app_id"] == "laplace.bar-proof":
                      niri(f"action close-window --id {window['id']}")
              retry(lambda _: not any(window["app_id"] == "laplace.bar-proof" for window in ipc("windows")))

          with subtest(f"Noctalia panels accept keyboard focus without a bar in session {generation}"):
              assert not json.loads(shell("status"))["barVisible"]
              for key, panel in (
                  ("meta_l-n", "control-center"),
                  ("meta_l-ctrl-spc", "control-center"),
                  ("meta_l-shift-e", "session"),
              ):
                  machine.send_key(key)
                  retry(lambda _: json.loads(shell("status"))["activePanelId"] == panel)
                  retry(lambda _: any(
                      layer["namespace"] == "noctalia-panel" and layer["keyboard_interactivity"] != "None"
                      for layer in ipc("layers")
                  ))
                  screenshot(f"noctalia-{panel}-{generation}")
                  machine.send_key("esc")
                  retry(lambda _: not json.loads(shell("status"))["panelOpen"])

          if generation == 1:
              with subtest("launcher restarts preserve applications without leaking the extension runtime"):
                  machine.send_key("meta_l-r")
                  retry(lambda _: any(layer["namespace"] == "vicinae" for layer in ipc("layers")), timeout_seconds=60)
                  wait_for_text("Search for anything")
                  machine.send_key("ctrl-a")
                  machine.send_chars("LaplaceSessionProof")
                  wait_for_text("Results \\(1\\)")
                  screenshot("desktop-launcher")
                  machine.send_key("ret")
                  retry(lambda _: any(window["app_id"] == "laplace.launcher-proof" for window in ipc("windows")), timeout_seconds=60)
                  application = next(window for window in ipc("windows") if window["app_id"] == "laplace.launcher-proof")
                  user("systemctl --user restart vicinae.service")
                  pids["vicinae"] = int(user("systemctl --user show vicinae.service -p MainPID --value"))
                  assert any(window["pid"] == application["pid"] for window in ipc("windows"))
                  machine.succeed(f"test -e /proc/{application['pid']}")
                  niri(f"action close-window --id {application['id']}")
                  retry(lambda _: not any(window["id"] == application["id"] for window in ipc("windows")), timeout_seconds=60)

              with subtest("the configured file chooser portal returns the selected file"):
                  user("printf 'portal proof\\n' >$HOME/portal-proof.txt")
                  niri("action spawn -- /bin/sh -c " + q(
                      "GTK_USE_PORTAL=1 ${desktopPkgs.zenity}/bin/zenity --file-selection "
                      "--title=PortalFileChooser --filename=$HOME/portal-proof.txt "
                      ">/tmp/desktop-portal-result"
                  ))
                  retry(lambda _: any(window["title"] == "PortalFileChooser" for window in ipc("windows")))
                  dialog = next(window for window in ipc("windows") if window["title"] == "PortalFileChooser")
                  backend = json.loads(user(
                      "busctl --user --json=short call org.freedesktop.DBus /org/freedesktop/DBus "
                      "org.freedesktop.DBus GetConnectionUnixProcessID s org.freedesktop.impl.portal.desktop.gtk"
                  ))
                  assert dialog["pid"] == backend["data"][0], (dialog, backend)
                  niri(f"action focus-window --id {dialog['id']}")
                  screenshot("desktop-file-chooser")
                  machine.send_key("ret")
                  machine.wait_until_succeeds(
                      "test \"$(cat /tmp/desktop-portal-result)\" = /home/alice/portal-proof.txt"
                  )
                  retry(lambda _: not any(window["id"] == dialog["id"] for window in ipc("windows")))

              with subtest("the selected graphical Polkit agent authenticates"):
                  niri("action spawn -- /bin/sh -c " + q(
                      "/run/wrappers/bin/pkexec --disable-internal-agent "
                      "${desktopPkgs.coreutils}/bin/id -u >/tmp/desktop-auth-result"
                  ))
                  def is_authentication(window: dict[str, Any]) -> bool:
                      return "polkit" in (window.get("app_id") or "").lower()
                  retry(lambda _: any(is_authentication(window) for window in ipc("windows")), timeout_seconds=60)
                  prompt = next(window for window in ipc("windows") if is_authentication(window))
                  niri(f"action focus-window --id {prompt['id']}")
                  screenshot("desktop-authentication")
                  machine.send_chars("desktop-smoke\n")
                  machine.wait_until_succeeds("test \"$(cat /tmp/desktop-auth-result)\" = 0")
                  retry(lambda _: not any(is_authentication(window) for window in ipc("windows")))

              with subtest("Noctalia locks and authenticates the disposable session"):
                  assert shell("session lock") == "ok"
                  retry(lambda _: json.loads(shell("status"))["locked"])
                  session_id = q(session_environment["XDG_SESSION_ID"])
                  machine.wait_until_succeeds(
                      f"test \"$(loginctl show-session {session_id} -p LockedHint --value)\" = yes"
                  )
                  wait_for_text("Type your password")
                  screenshot("desktop-locked")
                  machine.send_chars("bad-password\n")
                  wait_for_text("Authentication fail")
                  assert json.loads(shell("status"))["locked"]
                  machine.send_chars("desktop-smoke\n")
                  retry(lambda _: not json.loads(shell("status"))["locked"])
                  machine.wait_until_succeeds(
                      f"test \"$(loginctl show-session {session_id} -p LockedHint --value)\" = no"
                  )
                  screenshot("desktop-unlocked")

          with subtest(f"native logout {generation} tears down session-owned processes"):
              cgroups = [user(f"systemctl --user show {unit}.service -p ControlGroup --value") for unit in units]
              machine.send_key("meta_l-shift-e")
              retry(lambda _: json.loads(shell("status"))["activePanelId"] == "session")
              machine.send_key("2")
              wait_for_text("exit niri")
              machine.send_key("ret")
              machine.wait_until_tty_matches("1", "login: ")
              for unit in units + ["graphical-session"]:
                  suffix = ".target" if unit == "graphical-session" else ".service"
                  machine.wait_until_succeeds(user_command(
                      f"case $(systemctl --user show {unit}{suffix} -p ActiveState --value) in inactive|failed) ;; *) exit 1;; esac"
                  ), timeout=60)
              for pid in pids.values():
                  machine.succeed(f"test ! -e /proc/{pid}")
              for cgroup in cgroups:
                  path = q("/sys/fs/cgroup" + cgroup + "/cgroup.procs")
                  machine.succeed(f"test ! -e {path} || test -z \"$(cat {path})\"")
              remaining = environment()
              for variable in ("WAYLAND_DISPLAY", "DISPLAY", "XDG_SESSION_TYPE", "XDG_CURRENT_DESKTOP", "NIRI_SOCKET"):
                  assert variable not in remaining, (variable, remaining)
              machine.fail(user_command(
                  "busctl --user call org.freedesktop.DBus /org/freedesktop/DBus "
                  "org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications"
              ))
              previous_pids = pids
    '';
  }
