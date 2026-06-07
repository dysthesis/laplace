{lib, ...}: let
  inherit
    (lib)
    mkOption
    mkEnableOption
    ;
  inherit (lib.lists) unique;

  inherit
    (lib.types)
    listOf
    str
    ;
in {
  options.mnemosyne = {
    enable = mkEnableOption "Whether to enable state persistence for ephemeral root";
    persistDir = mkOption {
      type = str;
      description = "Where to store the persisted directories (without trailing slash)";
      default = "/nix/persist";
    };
    dirs = mkOption {
      type = listOf str;
      description = "Directories to persist. Each module contributes its own paths; the merged list is deduplicated.";
      apply = unique;
      default = [];
    };
    mountOpts = mkOption {
      type = listOf str;
      description = "List of mount options for the persisted directories";
      default = [
        "bind" # We want to bind-mount the paths
        "X-fstrim.notrim" # We don't need to trim bind mounts
        "x-gvfs-hide" # We want to hide the mounts from file managers
      ];
    };
  };
}
