{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkIf
    mkDefault
    mkOption
    types
    ;
  cfg = config.laplace.docker;
in {
  options.laplace.docker = {
    enable = mkEnableOption "Whether or not to enable Docker.";
    dataDir = mkOption {
      default = "/var/cache/containers/storage";
      type = types.str;
      description = "Where to store states to persist";
    };
  };
  config = mkIf cfg.enable {
    mnemosyne.dirs = [cfg.dataDir];

    virtualisation = {
      oci-containers.backend = mkDefault "podman";
      podman = {
        enable = true;
        autoPrune = {
          enable = true;
          flags = ["-af"];
        };

        extraPackages = with pkgs; [
          gvisor
        ];
      };
      containers.storage.settings = {
        storage = {
          driver = "overlay2";
          graphroot = cfg.dataDir; # Store this on disk, not tmpfs.
          runroot = "/run/containers/storage";
        };
      };
    };
  };
}
