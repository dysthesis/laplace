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
      description = "List of directories to persist";
      apply = unique;
      default =
        [
          "/etc/nixos"
          "/etc/NetworkManager/system-connections"
          "/etc/ssh"
          "/var/lib/bluetooth"
          "/var/lib/pipewire"
          "/etc/secrets"
        ]
        ++ lib.optionals config.laplace.services.miniflux.enable [
          "/var/lib/private/miniflux"
          "/var/lib/postgresql"
        ]
        ++ lib.optionals config.laplace.network.vpn.enable [
          "/etc/mullvad-vpn"
          "/var/cache/mullvad-vpn"
        ]
        ++ lib.optionals config.laplace.services.forgejo.enable [
          config.services.forgejo.stateDir
          config.services.postgresql.dataDir
        ]
        ++ lib.optionals config.laplace.services.tailscale.enable [
          "/var/lib/tailscale"
        ]
        ++ lib.optionals config.laplace.services.llm.enable [
          "/var/lib/private/ollama"
          "/var/lib/private/open-webui"
        ]
        ++ lib.optionals config.laplace.virtualisation.enable ["/var/lib/libvirt"]
        ++ lib.optionals config.laplace.security.secure-boot.enable ["/var/lib/sbctl"]
        ++ lib.optionals config.laplace.docker.enable [
          config.laplace.docker.dataDir
        ]
        ++ lib.optionals config.laplace.services.llm.enable [config.laplace.services.llm.dataDir]
        ++ lib.optionals config.laplace.services.radicle.enable [config.laplace.services.radicle.dataDir];
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
