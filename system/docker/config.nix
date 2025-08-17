{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.docker;
in {
  config = mkIf cfg.enable {
    virtualisation = {
      podman = {
        enable = true;
        autoPrune = {
          enable = true;
          flags = ["-af"];
        };

        # Extra packages to be installed in the Podman wrapper
        extraPackages = with pkgs; [
          podman-compose
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
