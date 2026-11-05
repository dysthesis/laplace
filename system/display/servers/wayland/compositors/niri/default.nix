{
  name = "niri";
  protocol = "wayland";
  logout = {
    pkgs,
    lib,
  }: [(lib.getExe pkgs.niri) "msg" "action" "quit"];
  configure = {
    pkgs,
    config,
    lib,
    utils,
    terminal,
    launcher,
    logout,
    barPackage,
    shellPackage,
    ...
  }: let
    integrated = shellPackage != null;
    niri = pkgs.unstable.callPackage ../../../../../../user/wrapped/niri {
      inherit pkgs lib config terminal launcher integrated;
      shellCommand =
        if integrated
        then [(lib.getExe shellPackage)]
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
    laplace.wm = {
      protocol = "wayland";
      login = [(lib.getExe' niri "niri-session")];
      inherit logout;
    };
    laplace.display.checkCommands = [
      ''
        ${lib.getExe niri} validate
        test -x ${lib.escapeShellArg (builtins.head terminal.launch)}
        ${lib.optionalString (barPackage != null) "test -x ${lib.getExe barPackage}"}
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
      // lib.optionalAttrs (barPackage != null) {
        waybar = sessionService "Waybar status bar" [(lib.getExe barPackage)];
      }
      // lib.optionalAttrs (!integrated) {
        swaybg = sessionService "Wayland background" [(lib.getExe pkgs.swaybg) "-i" "${../../../../../../user/assets/wallpaper.png}" "-m" "fill"];
        dunst = sessionService "Dunst notification daemon" [(lib.getExe pkgs.configured.dunst)];
      };
  };
}
