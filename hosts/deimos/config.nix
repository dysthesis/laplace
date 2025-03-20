_: {
  config = {
    laplace = {
      harden = [ "kernel" ];
      profiles = [ "desktop" ];
      hardware = {
        cpu = [ "amd" ];
        gpu = [ "amd" ];
        monitors = [
          {
            name = "HDMI-A-0";
            width = 1920;
            height = 1080;
            refreshRate = 60;
          }
          {
            name = "DisplayPort-1";
            width = 1920;
            height = 1080;
            refreshRate = 165;
            primary = true;
          }
        ];
      };

      bootloader = "systemd-boot";

      network = {
        bluetooth.enable = true;
        wifi.enable = true;
        dnscrypt-proxy.enable = true;
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

      users = [ "demiurge" ];
      display.servers = [ "xorg" ];

      virtualisation.enable = true;
      nh = {
        enable = true;
        flakePath = "/home/demiurge/Documents/Projects/laplace";
      };
    };

    mnemosyne.enable = true;
    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";
  };
}
