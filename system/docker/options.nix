{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  options.laplace.docker = {
    enable = mkEnableOption "Whether or not to enable Docker.";
    dataDir = mkOption {
      default = "/var/cache/containers/storage";
      type = types.str;
      description = "Where to store states to persist";
    };
  };
}
