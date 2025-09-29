{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.profiles;

  browser = ["zen"];

  xdgAssociations = type: program: list:
    builtins.listToAttrs (
      map (e: {
        name = "${type}/${e}";
        value = program;
      })
      list
    );

  browserTypes =
    (xdgAssociations "application" browser [
      "json"
      "x-extension-htm"
      "x-extension-html"
      "x-extension-shtml"
      "x-extension-xht"
      "x-extension-xhtml"
      "xhtml+xml"
    ])
    // (xdgAssociations "x-scheme-handler" browser [
      "about"
      "chrome"
      "ftp"
      "http"
      "https"
      "unknown"
    ]);

  # XDG MIME types
  associations = builtins.mapAttrs (_: v: (map (e: "${e}.desktop") v)) (
    {
      "application/pdf" = ["org.pwmt.zathura-pdf-mupdf"];
      "text/html" = browser;
      "text/plain" = ["Helix"];
      "inode/directory" = ["yazi"];
      "x-scheme-handler/magnet" = ["transmission-gtk"];
      # Full entry is org.telegram.desktop.desktop
      "x-scheme-handler/tg" = ["org.telegram.desktop"];
      "x-scheme-handler/tonsite" = ["org.telegram.desktop"];
    }
    // browserTypes
  );
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
      user.services = {
        syncthing = {
          enable = true;
          description = "Syncthing";
          unitConfig.partOf = ["default.target"];

          script =
            # bash
            ''
              ${lib.getExe pkgs.syncthing} \
                -no-browser \
                -no-restart \
                -logflags=0
            '';

          wantedBy = ["default.target"];
        };
      };
    };
    fonts.packages = with pkgs;
    with inputs.babel.packages.${system}; [
      fast-fonts
      atkinson-hyperlegible-next
      noto-fonts
      noto-fonts-extra
      noto-fonts-emoji
      noto-fonts-cjk-sans
      terminus_font
      jbcustom-nf
      sf-pro
      georgia-fonts
      newcomputermodern
      nerd-fonts.jetbrains-mono
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
      libinput = {
        enable = true;
        mouse = {
          accelProfile = "flat";
          accelSpeed = "0.75";
          naturalScrolling = true;
        };
        touchpad = {
          naturalScrolling = true;
          accelProfile = "flat";
          accelSpeed = "0.75";
        };
      };
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
        # PYTORCH_ROCM_ARCH = "gfx1030";
        # HSA_OVERRIDE_GFX_VERSION = "10.3.0";
        # HCC_AMDGPU_TARGET = "gfx1030";
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
      mime = {
        enable = true;
        defaultApplications = associations;
      };
      sounds.enable = true;
      portal = {
        enable = true;
        extraPortals = [pkgs.xdg-desktop-portal-gtk];
      };
    };
  };
}
