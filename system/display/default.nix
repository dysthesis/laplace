{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf;
  inherit (lib.babel.modules) importInDirectory;
  inherit (lib.babel.path) getDirectories;
  inherit
    (lib.types)
    listOf
    enum
    ;

  elems = getDirectories ./.;
in {
  options.laplace.display = mkOption {
    type = listOf (enum elems);
    description = "Which display servers to enable";
    default = [];
  };

  config = mkIf (config.laplace.display != []) {
    location = {
      latitude = 33.9;
      longitude = 151.2;
    };
  };

  # config = mkIf !(config.laplace.display != [  ]) {
  # 	location = {
  #      latitude = 33.9;
  #      longitude = 151.2;
  #    };
  # };

  imports = importInDirectory ./.;
}
