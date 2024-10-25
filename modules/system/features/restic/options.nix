{lib, ...}: let
  inherit
    (lib)
    mkEnableOption
    mkOption
    ;

  inherit
    (lib.types)
    listOf
    str
    ;
in {
  options.laplace.features.restic = {
    enable = mkEnableOption "Whether or not to enable backups with restic";

    paths = mkOption {
      type = listOf str;
      description = "List of paths to back up";
      default = [];
    };

    targets = mkOption {
      type = listOf str;
      description = "List of paths to back up to";
      default = [];
    };
  };
}
