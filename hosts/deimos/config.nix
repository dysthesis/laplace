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
    # Pregen-box overrides, deimos-only — loki keeps the pack's conservative
    # settings while players are on it.
    services.minecraft-servers.servers.retirement-home = {
      # The pack's c2me config disables parallel worldgen (see
      # c2me-pregen.toml for the reasoning).
      files."config/c2me.toml" = ./c2me-pregen.toml;
      # Pregen ticks legitimately run tens of seconds (c2me mid-tick chunk
      # tasks), so any CPU competition (a kernel build, say) can push one past
      # 60 s and the vanilla watchdog kills the server — that's the
      # 2026-07-04 11:02 crash. No players here to protect; disable it.
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
        # Chunk pregen box: same module/seed as loki, so the world generated
        # here transplants 1:1. Started manually (autoStart off), driven via
        # the server console socket with Chunky; world rsyncs to loki after.
        # No discord bridge — nobody chats with a pregen run.
        minecraft.retirement-home = {
          enable = true;
          autoStart = false;
          openFirewall = false;
          # Worker count is pinned in c2me-pregen.toml (14), so heap no longer
          # gates parallelism — it just has to absorb the allocation churn of
          # 14 concurrent Terralith/Tectonic gens. 20 GiB + ~2.5 GiB JVM
          # off-heap leaves ~8 GiB for desktop and page cache on the 31 GiB
          # box; going higher starts eating the write-back cache the 300+ GB
          # of region/LOD writes depend on.
          memoryGb = 20;
        };

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
        wayland.compositor = "dwl";
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
