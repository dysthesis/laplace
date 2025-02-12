{lib, ...}: let
  inherit (lib) mkOption;
  inherit (lib.babel.modules) importInDirectory;
  inherit (lib.babel.path) getDirectories;
  inherit
    (lib.types)
    listOf
    enum
    ;

  elems = (getDirectories ./.) ++ ["none"];
in {
  options.laplace.hardware.cpu = mkOption {
    type = listOf (enum elems);
    # I only have AMD  devices
    description = "The manufaturer of the CPU";
    default = [];
  };

  imports = importInDirectory ./.;
}
