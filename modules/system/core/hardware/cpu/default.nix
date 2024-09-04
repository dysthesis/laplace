{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
  inherit
    (lib.laplace.modules)
    fromDirectories
    importInDirectory
    ;

  elems = fromDirectories ./.;
in {
  options.laplace.hardware.cpu = mkEnumOption {
    inherit elems;
    # I only have AMD  devices
    description = "The manufaturer of the CPU";
  };

  imports = importInDirectory ./.;
}
