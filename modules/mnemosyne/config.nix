# Adapted from https://github.com/sioodmy/dotfiles/blob/1c692cbf6af349a568eb6ca2213eefbc42c43f39/modules/staypls/default.nix
{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    map
    mkIf
    mkDefault
    mkMerge
    forEach
    ;
  inherit
    (lib.strings)
    concatStringsSep
    normalizePath
    removePrefix
    ;
  inherit (builtins) replaceStrings;
  cfg = config.mnemosyne;
  # Where each persisted directory is stored at.
  persistPath = path: normalizePath "${cfg.persistDir}${path}";
  # Which systemd service is responsible for mounting the persistence volume
  persistMountService =
    cfg.persistDir |> removePrefix "/" |> replaceStrings ["/"] ["-"] |> (x: "${x}.mount");
  # Compose an attribute set of bind mounts for the persisted directories.
  mkMounts = dirs:
    dirs
    |> map (path: {
      "${path}" = {
        device = persistPath path;
        fsType = "none";
        options = cfg.mountOpts;
      };
    })
    |> mkMerge;

  # Compose a script to create the necessary directories in the persisted state storage.
  mkSourcePaths = dirs: dirs |> (dirs: forEach dirs (path: "mkdir -p ${persistPath path}")) |> concatStringsSep "\n";
in {
  # TODO: Add a check to ensure that `cfg.persistDir` is on a persisted volume
  config = mkIf cfg.enable {
    # We need to run the systemd service very early in the boot process
    # so that the persisted state is available to the system from the
    # start.
    boot.initrd.systemd.enable = mkDefault true;
    # Mount the persisted direcotries to their proper paths.
    fileSystems = mkMounts cfg.dirs;
    # Ensure that the necessary paths exist in the persisted state storage.
    boot.initrd.systemd.services.make-source-of-persistent-dirs = {
      wantedBy = ["initrd-root-device.target"];
      before = ["sysroot.mount"];
      requires = [persistMountService];
      after = [persistMountService];
      serviceConfig.Type = "oneshot";
      unitConfig.DefaultDependencies = false;
      script = mkSourcePaths cfg.dirs;
    };
  };
}
