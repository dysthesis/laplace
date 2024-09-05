{pkgs, ...}: {
  config = {
    laplace = {
      hardware = {
        cpu = "amd";
        gpu = "amd";
        monitors = [
          {
            name = "eDP";
            width = 2256;
            height = 1504;
            refreshRate = 60;
            pos = {
              x = 0;
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
        secure-boot.enable = true;
        firewall.enable = true;
      };

      sound = {
        enable = true;
        server = "pipewire";
      };

      users.demiurge = {
        enable = true;
        useHomeManager = true;
      };

      features = {
        nh = {
          enable = true;
          flakePath = "/home/demiurge/Documents/Projects/laplace";
        };

        impermanence.enable = true;
        virtualisation.enable = true;

        hardening = {
          kernel.enable = true;
          malloc.enable = true;
        };

        docs.enable = false;
      };
    };

    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";

    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-120n.psf.gz";
    };

    system.stateVersion = "24.11";
  };
}
