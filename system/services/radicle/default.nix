{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.laplace.services.radicle;
in {
  options.laplace.services.radicle = {
    enable = mkEnableOption "Whether or not to enable Radicle Seed";

    dataDir = mkOption {
      default = "/etc/radicle";
      type = types.str;
      description = "Where to store states to persist";
    };
  };
  config = mkIf cfg.enable {
    services.radicle = {
      enable = true;
      node.openFirewall = true;
      privateKey = "${cfg.dataDir}/keys/radicle";
      publicKey = "${cfg.dataDir}/keys/radicle.pub";

      # settings = {
      #   web.pinned.repositories = [
      #     "rad:zNpNEwyLfo6z76EvGEr8LhCetqVD" # laplace
      #   ];
      #
      #   node = {
      #     seedingPolicy.default = "permissive";
      #   };
      # };
    };
  };
}
