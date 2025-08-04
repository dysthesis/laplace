_: {
  config = {
    laplace = {
      harden = ["kernel"];
      profiles = ["desktop"];
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
              x = 1920;
              y = 0;
            };
          }
          {
            name = "DP-3";
            width = 1920;
            height = 1080;
            refreshRate = 165.001007;
            primary = true;
            pos = {
              x = 0;
              y = 0;
            };
          }
        ];
      };

      bootloader = "systemd-boot";
      docker.enable = true;

      network = {
        bluetooth.enable = true;
        wifi.enable = true;
        vpn.enable = false;
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
        firewall.enable = true;
      };

      sound = {
        enable = true;
        server = "pipewire";
      };

      impermanence.enable = true;

      users = ["demiurge"];
      display.servers = ["wayland"];

      services = {
        ollama.enable = true;
        searxng.enable = true;
      };

      virtualisation.enable = true;
      nh = {
        enable = true;
        flakePath = "/home/demiurge/Documents/Projects/laplace";
      };
    };

    mnemosyne.enable = true;
    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";

    networking.nameservers = [
      "9.9.9.9"
      "9.0.0.9"
    ];
    services.resolved = {
      enable = true;
      dnssec = "true";
      fallbackDns = [
        "9.9.9.9"
        "9.0.0.9"
      ];
      dnsovertls = "true";
    };
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };
  };
}
