{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (builtins) elem;
  cfg = config.laplace.profiles;
in {
  config = mkIf (elem "desktop" cfg) {
    systemd = {
      services.seatd = {
        enable = true;
        description = "Seat management daemon";
        script = "${lib.getExe pkgs.seatd} -g wheel";
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "1";
        };
        wantedBy = ["mult-user.target"];
      };
      user.services.syncthing = {
        enable = true;
        description = "Syncthing";
        unitConfig.partOf = ["default.target"];

        script =
          /*
          bash
          */
          ''
            ${lib.getExe pkgs.syncthing} \
              -no-browser \
              -no-restart \
              -logflags=0
          '';

        wantedBy = ["default.target"];
      };
    };
    fonts.packages = with pkgs;
    with inputs.babel.packages.${system}; [
      fast-fonts
      noto-fonts
      noto-fonts-extra
      noto-fonts-emoji
      noto-fonts-cjk-sans
      terminus_font
      jbcustom-nf
      sf-pro
      georgia-fonts
      (nerdfonts.override {
        fonts = ["JetBrainsMono"];
      })
    ];
    services = {
      logind = {
        lidSwitch = "suspend";
        lidSwitchExternalPower = "hibernate";
        extraConfig = ''
           HandlePowerKey=poweroff
          HibernateDelaySec=600
          SuspendState=mem
        '';
      };
      # libinput = {
      #   enable = true;
      #   mouse = {
      #     accelProfile = "flat";
      #     accelSpeed = "0.75";
      #     naturalScrolling = true;
      #   };
      #   touchpad = {
      #     naturalScrolling = true;
      #     accelProfile = "flat";
      #     accelSpeed = "0.75";
      #   };
      # };
      gnome.gnome-keyring.enable = true;
      dbus = {
        packages = with pkgs; [
          dconf
          gcr
          udisks2
        ];
        implementation = "broker";
        enable = true;
      };
    };
    environment = {
      sessionVariables = {
        GTK_USE_PORTAL = "1";
      };
      systemPackages = with pkgs; [xdg-utils];
    };
    security = {
      # For electron stuff
      chromiumSuidSandbox.enable = true;
      unprivilegedUsernsClone = true;

      # `login` means TTY login
      pam.services = {
        login.enableGnomeKeyring = true;
        swaylock.text = ''
          auth include login
        '';
      };
    };
    xdg = {
      autostart.enable = true;
      icons.enable = true;
      mime.enable = true;
      sounds.enable = true;
      portal = {
        enable = true;
        extraPortals = [pkgs.xdg-desktop-portal-gtk];
      };
    };
  };
}
