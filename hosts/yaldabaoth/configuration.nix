{
  config = {
    laplace = {
      hardware = {
        cpu = "amd";
        gpu = "amd";
      };
      bootloader = "systemd-boot";
    };

    system.stateVersion = "24.11";
  };
}
