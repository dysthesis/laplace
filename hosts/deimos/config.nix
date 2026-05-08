{
  pkgs,
  inputs,
  ...
}: let
  gemma4Revision = "462a98a12e28e2cbcfccaf78fe41e3e50235e6ae";
  gemma4Base = "https://huggingface.co/google/gemma-4-26B-A4B-it/resolve/${gemma4Revision}";
in {
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

      services.llm = {
        enable = false;
        # backend = "vllm";
        modelRegistry = {
          "qwen3.5" = {
            url = "https://huggingface.co/unsloth/Qwen3.5-35B-A3B-GGUF/resolve/main/Qwen3.5-35B-A3B-Q4_K_M.gguf";
            sha256 = "sha256-O0bRBmvJHMLWE+O8Is5pHdd+bw0zyQYGkNJM5t5JQ3U=";
          };
          "qwen3.6" = {
            url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
            sha256 = "sha256-rA4sEYngVfqjbv82FYDnnFvW+Odr/7TOVH8WfVPjGmE=";
          };
          "gemma4" = {
            url = "https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF/resolve/main/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf";
            sha256 = "34c746b1d50ab813e29cd46c4796e3f43c741901a582f93a67b55b9fc9687b35";
          };
          "nomic-embed-text" = {
            url = "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q4_K_M.gguf";
            sha256 = "sha256-1OOIiU4JzzgW6LCJbYHSZbVeep//mrA/6L9O9eESlaw=";
          };
        };

        vllm = {
          model = "google/gemma-4-26B-A4B-it";
          modelSource = "gemma4";
          modelRegistry.gemma4.files = {
            "chat_template.jinja" = {
              url = "${gemma4Base}/chat_template.jinja";
              hash = "sha256-lImcD5F9k/b+gclXRNHo3astIdOSKNLkrsH7KiW/9BM=";
            };

            "config.json" = {
              url = "${gemma4Base}/config.json";
              hash = "sha256-7Qwes2M953GQbpugBKRMxWNbzAbuIGIHfD0uiKUHB9M=";
            };

            "generation_config.json" = {
              url = "${gemma4Base}/generation_config.json";
              hash = "sha256-1CJrvjEX0tJTukYJcguoLGxM5GJ6mmrgU4fHiYOsA94=";
            };

            "model-00001-of-00002.safetensors" = {
              url = "${gemma4Base}/model-00001-of-00002.safetensors";
              # hash = lib.fakeHash;
              hash = "sha256-ESdoSXG7ykBGVDWlytadZ61gO/XmHG39VWH65KO8/bM=";
            };

            "model-00002-of-00002.safetensors" = {
              url = "${gemma4Base}/model-00002-of-00002.safetensors";
              hash = "sha256-qrRwM+HopJLvjlge+uHPNkeNBDNWfncps8Fyi8iXDbc=";
            };

            "model.safetensors.index.json" = {
              url = "${gemma4Base}/model.safetensors.index.json";
              hash = "sha256-kHgmpuRv9FQnK9bbH+5inVUxojA74imG2CWghx19x6c=";
            };

            "processor_config.json" = {
              url = "${gemma4Base}/processor_config.json";
              hash = "sha256-Mr30XSrUzCmggi3dFXoYLedmRPBBmmIo0VFJUlbpgTw=";
            };

            "tokenizer.json" = {
              url = "${gemma4Base}/tokenizer.json";
              hash = "sha256-zI06DONkZszBJ4v5h99fcdsXGbnKa0EYJk9Fy2J7/g8=";
            };

            "tokenizer_config.json" = {
              url = "${gemma4Base}/tokenizer_config.json";
              hash = "sha256-kMOjulv1OBg4Oljhp3bLys0qA41IEuqjc+FSLy0G898=";
            };
          };
          servedModelName = "gemma-4-26B";
          maxModelLen = 15250;
          gpuMemoryUtilization = 0.90;
        };

        contextSize = 64000;
        turboquant.enable = true;
        model = "qwen3.6";

        embedding = {
          enable = true;
          model = "nomic-embed-text";
        };

        search.enable = true;
        webui.enable = true;
      };

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
