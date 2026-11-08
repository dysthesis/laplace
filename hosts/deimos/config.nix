{
  pkgs,
  lib,
  ...
}: {
  config = {
    boot.binfmt.emulatedSystems = ["aarch64-linux"];
    programs.ccache.enable = true;
    environment.systemPackages = with pkgs; [
      android-tools
      usbutils

      polkit_gnome
    ];

    networking = {
      hostId = "47494eeb";
      defaultGateway = {
        address = "10.0.20.1";
        interface = "priv";
      };
      interfaces.priv.useDHCP = true;
      interfaces.mgmt.ipv4.addresses = [
        {
          address = "10.0.30.10";
          prefixLength = 24;
        }
      ];
      vlans = {
        mgmt = {
          id = 30;
          interface = "enp5s0";
        };
        priv = {
          id = 20;
          interface = "enp5s0";
        };
      };
    };
    laplace = {
      profiles = ["desktop"];
      desktop = with lib.components; {
        server = wayland;
        wm = dwl;
        term = foot;
      };
      hardware = {
        cpu = ["amd"];
        gpu = ["amd"];
        monitors = [
          {
            name = "HDMI-A-1";
            width = 1920;
            height = 1080;
            refreshRate = 60;
            pos = {
              x = 0;
              y = 0;
            };
          }
          {
            name = "DP-2";
            width = 1920;
            height = 1080;
            refreshRate = 165.001007;
            primary = true;
            pos = {
              x = 1920;
              y = 0;
            };
          }
        ];
      };

      bootloader = "systemd-boot";

      network = {
        bluetooth.enable = true;
        wifi.enable = true;
        dnscrypt-proxy.enable = false;
        tor = {
          enable = true;
          libera-chat-map.enable = true;
        };
      };

      security = {
        privesc = "doas";
        apparmor.enable = true;
        polkit.enable = true;
        secure-boot.enable = true;
        firewallPolicy.enable = true;
      };

      services = {
        tailscale = {
          enable = true;
          denySubnetRoutes = true;
        };
      };

      sound = {
        enable = true;
        server = "pipewire";
      };

      zram.enable = true;

      users = ["demiurge"];

      virtualisation.enable = true;
      nh = {
        enable = true;
        flakePath = "/home/demiurge/Documents/Projects/laplace";
      };
    };

    mnemosyne.enable = true;
    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;

      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
  };
}
