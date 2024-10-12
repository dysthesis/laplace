{lib, ...}: let
  inherit
    (lib)
    mkEnableOption
    mkOption
    ;

  inherit
    (lib.types)
    str
    path
    int
    ;
in {
  options.laplace.features.services.wallabag = {
    enable = mkEnableOption "Whether to enable Wallabag";

    subdomain = mkOption {
      type = str;
      default = "wallabag";
      description = "The subdomain to host Wallabag on";
    };

    port = mkOption {
      type = int;
      default = 8088;
      description = "The port to host Wallabag on";
    };

    dataPath = mkOption {
      type = path;
      default = "/usr/share/wallabag";
      description = "Where to store Wallabag's data";
    };
  };
}
