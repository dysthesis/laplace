{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.services.radicle;
in {
  config = mkIf cfg.enable {
    services.radicle = {
      enable = true;
      node.openFirewall = true;
      privateKeyFile = "${cfg.dataDir}/keys/radicle";
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
