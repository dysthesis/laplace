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

      features = {
        nh = {
          enable = true;
          flakePath = "/home/demiurge/Documents/Projects/laplace";
        };
      };
    };

    system.stateVersion = "24.11";
  };
}
