{
  inputs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf elem;
  hasDemiurge = elem "demiurge" config.laplace.users;
  hostName = config.networking.hostName or "";
in {
  imports = [inputs.sops-nix.nixosModules.sops];
  # phobos has no age key; chaos is the live ISO (not a sops recipient, and the
  # age key would live on a /nix/persist that doesn't exist on the ISO).
  sops = mkIf (!(elem hostName ["phobos" "chaos"])) {
    secrets = mkIf hasDemiurge {
      libera.owner = "demiurge";
    };
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/nix/persist/etc/secrets/age/keys.txt";
  };
}
