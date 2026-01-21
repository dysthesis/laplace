{
  pkgs,
  lib,
  inputs,
  ...
}: {
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
              x = 0;
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
              x = 1920;
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

      # services.llm = {
      #   enable = true;
      #   contextSize = 8129;
      #   modelRegistry = {
      #     qwen3 = {
      #       url = "https://huggingface.co/unsloth/Qwen3-30B-A3B-Instruct-2507-GGUF/resolve/main/Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf";
      #       sha256 = lib.fakeHash;
      #     };
      #   };
      #   model = "qwen3";
      #   # search = {
      #   #   enable = true;
      #   #   settings.customOpenAI = {
      #   #     apiUrl = "http://host.containers.internal:8080";
      #   #     apiKey = "llama-cpp";
      #   #   };
      #   # };
      # };

      services.miniflux.enable = true;

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
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server

      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
  };
}
