{
  pkgs,
  lib,
  ...
}: {
  config = {
    services.resolved.enable = lib.mkForce true;
    services.xserver = {
      dpi = 180;
      displayManager.importedVariables = [
        "GDK_SCALE"
        "GDK_DPI_SCALE"
        "QT_AUTO_SCREEN_SCALE_FACTOR"
      ];
    };
    environment.variables._JAVA_OPTIONS = "-Dsun.java2d.uiScale=2";
    boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
    boot.binfmt.emulatedSystems = ["aarch64-linux"];
    programs.ccache.enable = true;
    laplace = {
      services.tailscale = {
        enable = true;
        denySubnetRoutes = true;
      };
      profiles = ["desktop"];
      hardware = {
        cpu = ["amd"];
        gpu = ["amd"];
        monitors = [
          {
            name = "eDP-1";
            width = 2256;
            height = 1504;
            refreshRate = 60.0;
            pos = {
              x = 0;
              y = 0;
            };
          }
        ];
        battery.name = "BAT1";
        backlight.device = "amdgpu_bl0";
      };

      bootloader = "systemd-boot";

      network = {
        bluetooth.enable = true;
        dnscrypt-proxy.enable = true;
        wifi.enable = true;
        tor = {
          enable = false;
          libera-chat-map.enable = false;
        };
      };

      security = {
        privesc = "doas";
        apparmor.enable = true;
        polkit.enable = true;
        firewallPolicy.enable = true;
        fail2ban.enable = true;
      };

      sound = {
        enable = true;
        server = "pipewire";
      };

      zram.enable = true;

      display = {
        foot.fontSize = 5;
        fuzzel.fontSize = 13;
      };

      users = ["demiurge"];
      virtualisation.enable = true;
      nh = {
        enable = true;
        flakePath = "/home/demiurge/Documents/Projects/laplace";
      };
    };
    mnemosyne.enable = true;
  };
}
