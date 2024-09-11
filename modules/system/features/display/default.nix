{lib, ...}: let
  inherit (lib.laplace.options) mkEnumOption;
  inherit
    (lib.laplace.modules)
    fromDirectories
    importInDirectory
    ;
  elems = (fromDirectories ./.) ++ ["none"];
in {
  options.laplace.features.displayServer = mkEnumOption {
    # I only have AMD  devices
    inherit elems;
    description = "The manufaturer of the GPU";
    default = "none";
  };

  imports = importInDirectory ./.;
}
