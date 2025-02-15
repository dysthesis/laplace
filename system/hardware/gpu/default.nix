{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.babel.modules) importInDirectory;
  inherit (lib.babel.path) getDirectories;
  inherit (lib.types)
    listOf
    enum
    ;

  elems = getDirectories ./.;
in
{
  options.laplace.hardware.gpu = mkOption {
    # I only have AMD  devices
    type = listOf (enum elems);
    description = "The manufaturer of the GPU";
    default = [ ];
  };

  imports = importInDirectory ./.;
}
