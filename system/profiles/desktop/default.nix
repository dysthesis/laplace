{
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
    # Desktop-only firewall surface (moved off laplace.security.firewall so
    # servers don't inherit it): the Zotero LAN sync/discovery port.
    networking.firewall = {
      allowedTCPPorts = [23319]; # zotero
      allowedUDPPorts = [23319]; # zotero
    };
    systemd = {
      user.services = {
        syncthing = {
          enable = true;
          description = "Syncthing";
          wantedBy = ["default.target"];
          unitConfig.PartOf = ["default.target"];

          script = ''
            ${lib.getExe pkgs.syncthing} serve \
              --no-browser \
              --no-restart
          '';
        };
      };
    };
    fonts.packages = with pkgs; [
      fast-fonts
      atkinson-hyperlegible-next
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
      terminus_font
      jbcustom-nf
      literata
      et-book
      sf-pro
      georgia-fonts
      newcomputermodern
      nerd-fonts.jetbrains-mono
      nerd-fonts.iosevka
    ];
    services = {
      # Interactive outbound-connection prompts need a GUI to answer them, so
      # opensnitch belongs to the desktop profile rather than the generic
      # firewall module (which headless servers also enable).
      opensnitch.enable = true;
      seatd = {
        enable = true;
        group = "wheel";
      };
      logind = {
        settings.Login = {
          HandleLidSwitch = "suspend";
          HandleLidSwitchExternalPower = "hibernate";
          HandlePowerKey = "poweroff";
          HibernateDelaySec = 600;
          SuspendState = "mem";
        };
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
        PYTORCH_ROCM_ARCH = "gfx1030";
        HSA_OVERRIDE_GFX_VERSION = "10.3.0";
        HCC_AMDGPU_TARGET = "gfx1030";
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
        config.common.default = "gtk";
        extraPortals = [pkgs.xdg-desktop-portal-gtk];
      };
    };
  };
}
