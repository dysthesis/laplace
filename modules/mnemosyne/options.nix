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
        "bind"
        "X-fstrim.notrim" # Do not trim bind mounts.
        "x-gvfs-hide" # Hide these mounts from file managers.
      ];
    };
  };
}
