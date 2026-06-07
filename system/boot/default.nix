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
    tmp = {
      useTmpfs = true;
      cleanOnBoot = mkDefault (!config.boot.tmp.useTmpfs);
    };
  };
}
