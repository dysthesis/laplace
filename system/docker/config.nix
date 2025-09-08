{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.docker;
in
{
  config = mkIf cfg.enable {
    virtualisation = {
      docker = {
        enable = true;
        autoPrune = {
          enable = true;
          flags = [ "-af" ];
        };
        storageDriver = "btrfs";
        daemon.settings = {
          "data-root" = "/var/cache/docker";
          "log-driver" = "json-file";
        };

        # Extra packages to be installed in the Podman wrapper
        extraPackages = with pkgs; [
          gvisor
        ];
      };
      containers.storage.settings = {
        storage = {
          driver = "overlay2";
          graphroot = cfg.dataDir; # must live on disk, not tmpfs
          runroot = "/run/containers/storage";
        };
      };
    };
  };
}
