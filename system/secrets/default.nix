{
  inputs,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf elem;
  hasDemiurge = elem "demiurge" config.laplace.users;
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];
  sops = {
    secrets = mkIf hasDemiurge {
      libera.owner = "demiurge";
    };
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/nix/persist/etc/secrets/age/keys.txt";
  };
}
