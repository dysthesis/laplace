{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.features.restic;

  inherit
    (lib)
    mkIf
    fold
    ;
in {
  config = mkIf cfg.enable {
    sops.secrets."backblaze/env/${config.networking.hostName}".mode = "0700";
    sops.secrets."restic/${config.networking.hostName}" = {};

    services.restic.backups =
      fold
      (repository: acc:
        acc
        // {
          ${repository} = {
            initialize = true;

            inherit (cfg) paths;
            inherit repository;

            environmentFile = config.sops.secrets."backblaze/env/${config.networking.hostName}".path;
            passwordFile = config.sops.secrets."restic/${config.networking.hostName}".path;

            pruneOpts = [
              "--keep-daily 7"
              "--keep-weekly 5"
              "--keep-monthly 12"
            ];
          };
        })
      {}
      cfg.targets;
  };
}
