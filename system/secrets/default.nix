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
      # client_id + encryption_secret lines for Taskwarrior's TaskChampion sync
      # (tasks.dysthesis.com). The wrapped `task` stages this into ~/.config/task.
      taskwarrior_sync.owner = "demiurge";
    };
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/nix/persist/etc/secrets/age/keys.txt";
  };
}
