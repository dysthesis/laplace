{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
  inherit
    (lib.laplace.modules)
    importInDirectory
    fromDirectories
    ;

  elems = fromDirectories ./.;
in {
  config.boot.initrd.verbose = false;
  options.laplace.bootloader = mkEnumOption {
    inherit elems;
    description = "Which bootloader to use";
  };
  imports = importInDirectory ./.;
}
