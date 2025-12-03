{lib, ...}: let
  inherit (lib) mkOption;
  inherit
    (lib.types)
    listOf
    enum
    ;
  inherit
    (lib.babel.path)
    getDirectories
    ;
  inherit (lib.babel.modules) importInDirectory;
  options = getDirectories ./.;
in {
  options.laplace.harden = mkOption {
    type = listOf (enum options);
    default = [];
  };

  imports = importInDirectory ./.;
}
