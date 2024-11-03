{lib, ...}: let
  inherit
    (lib)
    mkEnableOption
    mkOption
    ;

  inherit
    (lib.types)
    path
    int
    str
    ;
in {
  options.laplace.features.services.tubearchivist = {
    enable = mkEnableOption "Whether or not to enable Tubearchivist";

    youtubePath = mkOption {
      type = path;
      description = "Where the library is stored";
      default = "/usr/share/tubearchivist/youtube";
    };

    cachePath = mkOption {
      type = path;
      description = "Where the library is stored";
      default = "/usr/share/tubearchivist/cache";
    };

    address = lib.mkOption {
      type = str;
      default = "localhost";
    };

    port = mkOption {
      type = int;
      description = "Which port Tubearchivist should be hosted in";
      default = 8000;
    };

    subdomain = mkOption {
      type = str;
      description = "The subdomain that Tubearchivist should be hosted on";
      default = "tube";
    };
  };
}
