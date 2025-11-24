{inputs, ...}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd # APU logic
    inputs.nixos-hardware.nixosModules.common-gpu-amd # AMD GPU support
  ];
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
        dnscrypt-proxy.enable = true;
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

      services.llm = {
        enable = true;
        contextSize = 8129;
        search = {
          enable = true;
          settings.customOpenAI = {
            apiUrl = "http://host.containers.internal:8080";
            apiKey = "llama-cpp";
            modelName = "gpt-oss-20b";
          };
        };
      };

      # Expose llama-cpp on the Podman bridge so Perplexica can reach it.
      # services.llama-cpp.host = "0.0.0.0";

      sound = {
        enable = true;
        server = "pipewire";
      };

      impermanence.enable = true;
      zram.enable = true;

      users = ["demiurge"];
      display.servers = ["wayland"];

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
      "1.1.1.1"
      "1.0.0.1"
    ];
    # services.resolved = {
    #   enable = true;
    #   dnssec = "true";
    #   fallbackDns = [
    #     "8.8.8.8"
    #     "8.0.0.8"
    #   ];
    #   dnsovertls = "true";
    # };
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };
  };
}
