{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
  ];
  config = {
    boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
    environment.systemPackages = with pkgs; [
      android-tools
      usbutils

      signal-desktop
      polkit_gnome
    ];

    security.polkit.enable = true;
    # Deimos-only pregen overrides; Loki keeps the pack defaults.
    services.minecraft-servers.servers.retirement-home = {
      # The pack's c2me config disables parallel worldgen (see
      # c2me-pregen.toml for the reasoning).
      files."config/c2me.toml" = ./c2me-pregen.toml;
      # World generation can exceed the watchdog limit; this host has no players.
      serverProperties.max-tick-time = -1;
    };

    # Pregen wins CPU contention against the desktop session (default
    # CPUWeight is 100). Only bites when cores are oversubscribed.
    systemd.services.minecraft-server-retirement-home.serviceConfig.CPUWeight = 1000;

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
        firewall.enable = true;
      };

      services = {
        tailscale = {
          enable = true;
          denySubnetRoutes = true;
        };
        llm = {
          enable = false;
          modelRegistry = {
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

      sound = {
        enable = true;
        server = "pipewire";
      };

      zram.enable = true;

      users = ["demiurge"];
      display = {
        servers = ["wayland"];
        wayland = {
          compositor = "niri";
          desktop.enable = true;
        };
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
