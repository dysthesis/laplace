{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault;
in {
  imports = [
    (lib.laplace.modules.mkSelector {
      dir = ./.;
      option = ["laplace" "bootloader"];
      multiple = false;
      extra = ["none"];
      default = "none";
      description = "Which bootloader to use";
    })
  ];

  config.boot = {
    initrd.verbose = mkDefault false;
    kernelParams = ["sysctl.vm.mem_profiling=never"];
    tmp = {
      useTmpfs = true;
      cleanOnBoot = mkDefault (!config.boot.tmp.useTmpfs);
    };
  };
}
