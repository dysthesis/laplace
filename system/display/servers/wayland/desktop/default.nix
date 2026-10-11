{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.display.wayland.desktop;
  display = config.laplace.display;
  palette = import ./palette.nix;
  sessionService = description: execStart: {
    inherit description;
    after = ["graphical-session-pre.target" "dbus.socket"];
    requires = ["dbus.socket"];
    partOf = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];
    serviceConfig = {
      ExecStart = execStart;
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
in {
  options.laplace.display.wayland.desktop.enable = lib.mkEnableOption "the integrated Niri desktop";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.elem "wayland" display.servers;
        message = "laplace.display.wayland.desktop.enable requires Wayland.";
      }
      {
        assertion = display.wayland.compositor == "niri";
        message = "laplace.display.wayland.desktop.enable requires Niri.";
      }
    ];

    environment.systemPackages = with pkgs.configured; [noctalia vicinae pkgs.ddcutil];

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
        (lib.getExe pkgs.configured.noctalia)
        // {
          path = [
            pkgs.ddcutil
          ];
        };

      vicinae =
        lib.recursiveUpdate
        (sessionService "Vicinae launcher" "${lib.getExe pkgs.configured.vicinae} server")
        {
          path = [
            config.system.path
            "/etc/profiles/per-user/demiurge"
          ];
          # Match upstream: restarting the launcher must not kill apps it launched.
          serviceConfig.KillMode = "process";
        };
      polkit-gnome = sessionService "Polkit authentication agent" "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
    };

    laplace.display.checkCommands = [
      ''
        ${lib.getExe pkgs.configured.noctalia} config validate
        ${lib.getExe pkgs.configured.vicinae} version
        test -r ${pkgs.configured.vicinae.themeFile}
        test -x ${lib.getExe pkgs.configured.swaylock}
        test -x ${lib.getExe pkgs.pwvucontrol}
        test -x ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
      ''
    ];
  };
}
