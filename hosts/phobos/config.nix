{
  config = {
    # reduce bootloader menu delay and tighten LUKS retry and timeout
    boot = {
      loader.timeout = 0;
      initrd.luks.devices."cryptroot" = {
        device = "/dev/disk/by-partlabel/disk-main-luks";
        crypttabExtraOpts = ["tries=1" "timeout=30"];
      };
    };

    laplace = {
      harden = [
        "kernel"
        # Keep malloc hardening enabled here. Zen already ships with
        # --enable-replace-malloc, but on this AMD laptop it still needs the
        # wrapper-side Zink workaround in user/wrapped/zen.
        # "malloc"
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
        # secure-boot.enable = true;
        firewall.enable = true;
        fail2ban.enable = true;
      };

      sound = {
        enable = true;
        server = "pipewire";
      };

      impermanence.enable = true;
      zram.enable = true;

      display = {
        servers = ["wayland"];
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
