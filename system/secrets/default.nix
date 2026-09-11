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
  sops = mkIf (!(elem hostName ["chaos"])) {
    secrets = mkIf hasDemiurge {
      libera.owner = "demiurge";
      # Radicale (cal.dysthesis.com) password for the demiurge htpasswd account.
      # vdirsyncer reads it at runtime via password.fetch; never staged to disk.
      khal_caldav.owner = "demiurge";
    };
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/nix/persist/etc/secrets/age/keys.txt";
  };
}
