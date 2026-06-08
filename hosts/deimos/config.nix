{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd # APU logic
    inputs.nixos-hardware.nixosModules.common-gpu-amd # AMD GPU support
  ];
  config = {
    boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
    laplace = {
      # harden = ["kernel"];
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
      # docker.enable = true;

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

      services = {
        tailscale = {
          enable = true;
          denySubnetRoutes = true;
        };
        llm = {
          enable = true;
          # backend = "vllm";
          modelRegistry = {
            # "qwen3.6-27b" = {
            #   url = "https://huggingface.co/unsloth/Qwen3.6-27B-MTP-GGUF/resolve/main/Qwen3.6-27B-Q4_K_M.gguf";
            #   sha256 = "sha256-p8vT7MDj+bMz7e5hrma8h+1xPF1JWHqDVYFHIu0yng8=";
            # };
            "qwen3.6-35b-a3b" = {
              url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q6_K.gguf";
              sha256 = "sha256-SZNbBK2IPC89TaYfZbYJ1Efa1n0LCEU7kKuwmhuzVGQ=";
            };
          };

          contextSize = 262144;
          model = "qwen3.6-35b-a3b";

          embedding = {
            enable = false;
            model = "nomic-embed-text";
          };

          search.enable = false;
          webui.enable = false;
        };
      };

      services.miniflux.enable = true;

      # Expose llama-cpp on the Podman bridge so Perplexica can reach it.
      # services.llama-cpp.host = "0.0.0.0";

      sound = {
        enable = true;
        server = "pipewire";
      };

      zram.enable = true;

      users = ["demiurge"];
      display.servers = ["wayland"];

      virtualisation.enable = true;
      nh = {
        enable = true;
        flakePath = "/home/demiurge/Documents/Projects/nix-config";
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
