{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
  inherit
    (lib.laplace.modules)
    fromDirectories
    importInDirectory
    ;
  elems = (fromDirectories ./.) ++ ["none"];
in {
  options.laplace.hardware.gpu = mkEnumOption {
    # I only have AMD  devices
    inherit elems;
    description = "The manufaturer of the GPU";
  };

  imports = importInDirectory ./.;
}
