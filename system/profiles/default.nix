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
  options = getDirectories ./.;
  inherit (lib.babel.modules) importInDirectory;
in {
  options.laplace.profiles = mkOption {
    type = listOf (enum options);
    default = [];
  };

  imports = importInDirectory ./.;
}
