_: {
  config = {
    laplace = {
      harden = [
        "kernel"
        # TODO: malloc hardening breaks Firefox and its derivatives.
        # Figure out if it's possible to work around that.
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
      docker.enable = true;
      nh = {
        enable = true;
        flakePath = "/home/demiurge/Documents/Projects/laplace";
      };
    };
    mnemosyne.enable = true;
  };
}
