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
      };
    };

    system.stateVersion = "24.11";
  };
}
