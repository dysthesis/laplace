{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    listOf
    enum
    ;
  inherit (lib.babel.modules) importInDirectory;
  inherit (lib.babel.modules) getDirectories;
  elems = getDirectories ./.;
in
{
  options.laplace.filesystems = mkOption {
    type = listOf (enum elems);
    description = "Which filesystems to enable support for";
    default = [ ];
  };

  imports = importInDirectory ./.;
}
