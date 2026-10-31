{
  pkgs,
  lib,
  ...
}: {
  config = {
    services.resolved.enable = lib.mkForce true;
    boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
    boot.binfmt.emulatedSystems = ["aarch64-linux"];
    programs.ccache.enable = true;
    laplace = {
      services.tailscale = {
        enable = true;
        denySubnetRoutes = true;
      };
      harden = [
        # Zen needs its Zink workaround with global malloc hardening on this AMD GPU.
      ];
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
        servers = ["wayland"];
        wayland = {
          compositor = "niri";
          desktop.enable = true;
        };
        hidpi = true;
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
