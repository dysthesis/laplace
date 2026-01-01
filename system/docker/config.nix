{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) 
    mkIf
    mkDefault
    ;
  cfg = config.laplace.docker;
in {
  config = mkIf cfg.enable {
    virtualisation = {
      oci-containers.backend = mkDefault "podman";
      podman = {
        enable = true;
        autoPrune = {
          enable = true;
          flags = ["-af"];
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
