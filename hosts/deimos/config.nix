{pkgs, ...}: {
  config = {
    laplace = {
      hardware = {
        cpu = ["amd"];
        gpu = ["amd"];
        monitors = [
          {
            name = "DP-1";
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
            refreshRate = 165;
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
        dnscrypt-proxy.enable = true;
      };

      security = {
        privesc = "doas";
        apparmor.enable = true;
        polkit.enable = true;
        secure-boot.enable = false;
        firewall.enable = true;
      };

      sound = {
        enable = true;
        server = "pipewire";
      };

      impermanence.enable = true;

      users = ["demiurge"];
      display = ["xorg"];

      virtualisation.enable = true;
      nh = {
        enable = true;
        flakePath = "~/Documents/Projects/laplace";
      };
    };

    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";
  };
}
