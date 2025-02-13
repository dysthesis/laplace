{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkOption
    mkEnableOption
    ;

  inherit
    (lib.types)
    listOf
    str
    ;
  addIf = cond: content:
    if cond
    then content
    else [];
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
      description = "List of directories to persist";
      default =
        [
          "/var/lib/nixos"
          "/etc/nixos"
          "/etc/NetworkManager"
          "/etc/secrets"
          "/etc/NetworkManager/system-connections"
        ]
        ++ addIf config.laplace.virtualisation.enable ["/var/lib/libvirt"]
        ++ addIf config.laplace.security.secure-boot.enable ["/etc/secureboot"];
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
