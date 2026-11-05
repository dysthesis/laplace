{
  protocol = "wayland";
  module = {
    pkgs,
    config,
    lib,
    utils,
    desktopSelection,
    ...
  }: let
    integrated = desktopSelection.shell != null;
    terminal = import desktopSelection.terminal {
      inherit pkgs lib;
      foot = pkgs.configured.foot;
    };
    launcher = import desktopSelection.launcher {inherit pkgs lib;};
    logout = [(lib.getExe pkgs.niri) "msg" "action" "quit"];
    bar =
      if desktopSelection.bar == null
      then null
      else pkgs.unstable.callPackage desktopSelection.bar {inherit pkgs lib config;};
    shell =
      if !integrated
      then null
      else
        pkgs.unstable.callPackage ../../../../../../user/wrapped/noctalia {
          inherit pkgs lib config logout;
          launcherOpen = launcher.open;
          barEnabled = bar == null;
        };
    niri = pkgs.unstable.callPackage ../../../../../../user/wrapped/niri {
      inherit pkgs lib config terminal launcher integrated;
      shellCommand =
        if integrated
        then [(lib.getExe shell)]
        else null;
    };
    sessionService = description: argv: {
      inherit description;
      after = ["graphical-session-pre.target"];
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        ExecStart = utils.escapeSystemdExecArgs argv;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  in {
    imports = lib.optional integrated ({...}:
      import desktopSelection.shell {
        inherit config lib pkgs utils shell launcher;
      });

    assertions = [
      {
        assertion = desktopSelection.shell == null || desktopSelection.shell == ../../desktop;
        message = "Niri supports the existing standalone or Noctalia shell bundle.";
      }
      {
        assertion = desktopSelection.bar == ../../../../../../user/wrapped/waybar || (integrated && desktopSelection.bar == null);
        message = "Niri requires Noctalia's bar or the configured Niri Waybar adapter.";
      }
      {
        assertion =
          desktopSelection.launcher
          == (
            if integrated
            then ../../../../launchers/vicinae.nix
            else ../../../../launchers/fuzzel.nix
          );
        message = "Integrated Niri requires Vicinae application launch and clipboard history; standalone Niri uses Fuzzel.";
      }
    ];

    laplace.wm = {
      protocol = "wayland";
      login = [(lib.getExe' niri "niri-session")];
      inherit logout;
    };
    laplace.display.checkCommands = [
      ''
        ${lib.getExe niri} validate
        test -x ${lib.escapeShellArg (builtins.head terminal.launch)}
        ${lib.optionalString (bar != null) "test -x ${lib.getExe bar}"}
        ${lib.optionalString (!integrated) ''
          test -x ${lib.getExe launcher.package}
          test -x ${lib.getExe pkgs.configured.dunst}
        ''}
      ''
    ];

    programs.niri = {
      enable = true;
      package = niri;
      useNautilus = false;
    };
    systemd.user.services =
      {
        niri-swallow = sessionService "Automatic terminal window swallowing" [
          (lib.getExe pkgs.python3)
          "${../../../../../../user/wrapped/niri/scripts/niri-swallow.py}"
          terminal.appId
        ];
      }
      // lib.optionalAttrs (bar != null) {
        waybar = sessionService "Waybar status bar" [(lib.getExe bar)];
      }
      // lib.optionalAttrs (!integrated) {
        swaybg = sessionService "Wayland background" [(lib.getExe pkgs.swaybg) "-i" "${../../../../../../user/assets/wallpaper.png}" "-m" "fill"];
        dunst = sessionService "Dunst notification daemon" [(lib.getExe pkgs.configured.dunst)];
      };
  };
}
