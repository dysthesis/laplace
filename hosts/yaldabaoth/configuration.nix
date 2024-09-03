{
  config = {
    laplace = {
      hardware = {
        cpu = "amd";
        gpu = "amd";
      };

      bootloader = "systemd-boot";

      network = {
        wifi.enable = true;
        dnscrypt-proxy.enable = true;
      };

      security = {
        privesc = "doas";
      };

      features = {
        nh = {
          enable = true;
          flakePath = "/home/demiurge/Documents/Projects/laplace";
        };

        docs.enable = false;
      };
    };

    system.stateVersion = "24.11";
  };
}
