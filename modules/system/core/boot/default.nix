{
  config,
  lib,
  ...
}: let
  inherit (lib.laplace.options) mkEnumOption;
  inherit
    (lib.laplace.modules)
    importInDirectory
    fromDirectories
    ;
  inherit (lib) mkDefault;

  elems = fromDirectories ./.;
in {
  config.boot = {
    initrd.verbose = false;
    tmp = {
      useTmpfs = true;
      cleanOnBoot = mkDefault (!config.boot.tmp.useTmpfs);
    };
  };
  options.laplace.bootloader = mkEnumOption {
    inherit elems;
    description = "Which bootloader to use";
  };
  imports = importInDirectory ./.;
}
