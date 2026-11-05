{
  config,
  lib,
  pkgs,
  utils,
  shell,
  launcher,
  ...
}: let
  palette = import ./palette.nix;
  sessionService = description: argv: {
    inherit description;
    after = ["graphical-session-pre.target" "dbus.socket"];
    requires = ["dbus.socket"];
    partOf = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];
    serviceConfig = {
      ExecStart = utils.escapeSystemdExecArgs argv;
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
in {
  environment.systemPackages = [shell launcher.package pkgs.ddcutil];

  laplace.gtk = {
    cssText = lib.mkDefault (import ./gtk.nix palette);
    fontName = lib.mkDefault "Atkinson Hyperlegible Next 10";
    preferDark = lib.mkDefault true;
    cursor.size = lib.mkDefault 24;
  };

  systemd.user.services = {
    niri.enableDefaultPath = false;
    noctalia =
      sessionService "Desktop shell and notifications"
      [(lib.getExe shell)]
      // {
        path = [
          pkgs.ddcutil
        ];
      };

    vicinae =
      lib.recursiveUpdate
      (sessionService "Vicinae launcher" [(lib.getExe launcher.package) "server"])
      {
        path = [
          config.system.path
          "/etc/profiles/per-user/demiurge"
        ];
        # A launcher restart must not stop applications that it started.
        serviceConfig.KillMode = "process";
      };
    polkit-gnome = sessionService "Polkit authentication agent" ["${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"];
  };

  laplace.display.checkCommands = [
    ''
      ${lib.getExe shell} config validate
      ${lib.getExe launcher.package} version
      test -r ${launcher.package.themeFile}
      test -x ${lib.getExe pkgs.configured.swaylock}
      test -x ${lib.getExe pkgs.pwvucontrol}
      test -x ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    ''
  ];
}
