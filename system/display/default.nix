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
  options.laplace.display = mkOption {
    type = listOf (enum elems);
    description = "Which display servers to enable";
    default = [ ];
  };

  imports = importInDirectory ./.;
}
