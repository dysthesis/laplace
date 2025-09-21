{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    foldl'
    map
    ;

  inherit (lib.types)
    attrsOf
    bool
    listOf
    nullOr
    str
    enum
    submodule
    ;

  inherit (lib.strings)
    concatStringsSep
    ;

  addIf = cond: content: if cond then content else [ ];

  typeHelpers = import ./types.nix { inherit lib; };
  inherit (typeHelpers)
    ensureAbsolutePath
    ensureAbsoluteNoTrailingSlash
    ensureRelativePath
    mountOptionsType
    mkDirectoryEntryType
    mkFileEntryType
    userPersistenceModule
    userPersistenceType;

  findDuplicates = values:
    let
      counts = foldl'
        (acc: value:
          acc // {
            "${value}" = (acc.${value} or 0) + 1;
          })
        { }
        values;
    in
    lib.attrNames (lib.filterAttrs (_: count: count > 1) counts);

in
{
  options.mnemosyne = {
    enable = mkEnableOption "Whether to enable state persistence for ephemeral root";
    persistDir = mkOption {
      type = str;
      description = ''
        Root of the persistent storage tree. All system paths are
        stored relative to this directory, and per-user state defaults
        to a sibling directory (e.g. `/persist/<user>`) unless overridden.

        Must be absolute and must not end with a slash.
      '';
      default = "/nix/persist";
      apply = value: ensureAbsoluteNoTrailingSlash "persistDir" value;
    };
    dirs = mkOption {
      type = listOf str;
      description = ''
        Absolute system directories that should be bind-mounted from
        persistent storage. Each path is stored verbatim under
        `mnemosyne.persistDir`.
      '';
      apply = paths:
        let
          checked = map (path: ensureAbsolutePath "dirs" path) paths;
          duplicates = findDuplicates checked;
        in
        if duplicates != [ ] then
          throw "mnemosyne.dirs contains duplicate entries: ${concatStringsSep ", " duplicates}"
        else
          checked;
      default = [
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
      ++ addIf config.laplace.services.ollama.enable [
        "/var/lib/private/ollama"
        "/var/lib/private/open-webui"
      ]
      ++ addIf config.laplace.virtualisation.enable [ "/var/lib/libvirt" ]
      ++ addIf config.laplace.security.secure-boot.enable [ "/var/lib/sbctl" ]
      ++ addIf config.laplace.virtualisation.enable [ "/var/lib/libvirt" ]
      ++ addIf config.laplace.security.secure-boot.enable [ "/var/lib/sbctl" ]
      ++ addIf config.laplace.docker.enable [
        config.laplace.docker.dataDir
        config.virtualisation.docker.daemon.settings."data-root"
      ]
      ++ addIf config.laplace.services.ollama.enable [ config.laplace.services.ollama.dataDir ]
      ++ addIf config.laplace.services.radicle.enable [ config.laplace.services.radicle.dataDir ];
    };
    mountOpts = mkOption {
      type = listOf str;
      description = ''
        Default mount options applied to directory entries. Users can
        append or replace these on a per-entry basis via
        `mnemosyne.users.<name>.directories[].mountOptions`.
      '';
      default = [
        "bind" # We want to bind-mount the paths
        "X-fstrim.notrim" # We don't need to trim bind mounts
        "x-gvfs-hide" # We want to hide the mounts from file managers
      ];
    };
    users = mkOption {
      type = attrsOf (submodule ({ name, ... }: userPersistenceModule name));
      default = { };
      description = ''
        Per-user persistence declarations. Each attribute key must match
        a user defined under `users.users`. Directories and files are
        interpreted relative to the user's home and persisted under
        `mnemosyne.persistDir` (optionally within
        `persistSubdir`). Mount options can be appended to or replace the
        system defaults on a per-entry basis.
      '';
    };
  };
}
