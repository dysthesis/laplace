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
  options.laplace.display = mkOption {
    # I only have AMD  devices
    type = listOf (enum elems);
    description = "Which display servers to enable";
    default = [];
  };

  imports = importInDirectory ./.;
}
