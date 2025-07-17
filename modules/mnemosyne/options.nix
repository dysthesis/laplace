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
          "/etc/nixos"
          "/etc/NetworkManager/system-connections"
          "/etc/ssh"
          "/var/lib/bluetooth"
          "/var/lib/pipewire"
          "/etc/secrets"
        ]
        ++ addIf config.laplace.services.miniflux.enable [
          "/var/lib/private/miniflux"
          "/var/lib/postgresql"
        ]
        ++ addIf config.laplace.network.vpn.enable [
          "/etc/mullvad-vpn"
          "/var/cache/mullvad-vpn"
        ]
        ++ addIf config.laplace.services.ollama.enable ["/var/lib/private/ollama" "/var/lib/private/open-webui"]
        ++ addIf config.laplace.virtualisation.enable ["/var/lib/libvirt"]
        ++ addIf config.laplace.security.secure-boot.enable ["/var/lib/sbctl"];
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
