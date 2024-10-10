{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (builtins) attrNames;

  inherit
    (lib)
    mkIf
    filterAttrs
    fold
    ;

  cfg = config.laplace.features.impermanence;
  addIf = cond: content:
    if cond
    then content
    else [];
in {
  imports = [inputs.impermanence.nixosModule];

  config = mkIf cfg.enable {
    programs.fuse.userAllowOther = true;
    environment.persistence."${cfg.persistDir}" = {
      hideMounts = true;
      directories =
        [
          "/var/lib/nixos"
          "/etc/nixos"
          "/etc/NetworkManager"
          # "/etc/ssh"
          # Sops stuff
          "/etc/secrets"
          "/etc/NetworkManager/system-connections"
        ]
        ++ addIf config.laplace.features.virtualisation.enable ["/var/lib/libvirt"]
        ++ addIf config.laplace.features.services.miniflux.enable
        [
          {
            directory = "/var/lib/private/miniflux";
            mode = "0750";
            user = "miniflux";
            group = "miniflux";
          }
          {
            directory = "/var/lib/postgresql";
            user = "postgres";
            group = "postgres";
          }
        ]
        ++ addIf config.laplace.network.bluetooth.enable ["/var/lib/bluetooth"]
        ++ addIf config.laplace.security.secure-boot.enable ["/etc/secureboot"]
        ++ addIf config.laplace.features.services.traefik.enable [config.services.traefik.dataDir]
        ++ addIf config.laplace.features.services.forgejo.enable [config.services.forgejo.stateDir]
        ++ addIf config.laplace.features.services.owntracks.enable [config.services.mosquitto.dataDir]
        ++ addIf config.laplace.features.services.calibre-web.enable [
          {
            directory = "/var/lib/calibre-server";
            mode = "0750";
            user = "calibre-server";
            group = "calibre-server";
          }
          {
            directory = "${config.services.calibre-web.dataDir}";
            mode = "0750";
            user = "calibre-web";
            group = "calibre-web";
          }
        ];

      files =
        ["/etc/machine-id"]
        ++ addIf config.laplace.network.dnscrypt-proxy.enable ["/etc/dnscrypt-proxy/blocked-names.txt"];

      users = let
        enabledUsers =
          attrNames
          (filterAttrs
            (_name: value: value.enable)
            config.laplace.users);

        userDirs = user:
          [
            "Documents"
            "Downloads"
            "Music"
            "Pictures"
            "Sync"
            ".mozilla"
            ".cache/BraveSoftware"
            ".cache/nix-index"
            ".cache/Proton"
            ".config/Proton"
            ".config/Signal"
            ".config/BraveSoftware"
            ".config/vesktop"
            {
              directory = ".config/sops";
              mode = "0600";
            }
            ".local/share/calcurse"
            ".local/share/BraveSoftware"
            {
              directory = ".gnupg";
              mode = "0700";
            }
            {
              directory = ".ssh";
              mode = "0700";
            }
            {
              directory = ".local/share/keyrings";
              mode = "0700";
            }
          ]
          ++ addIf (config.home-manager.users.${user}.programs.password-store.enable or false) [".local/share/password-store"]
          ++ addIf (config.home-manager.users.${user}.programs.atuin.enable or false) [".local/share/atuin"]
          ++ addIf (config.home-manager.users.${user}.programs.direnv.enable or false) [".local/share/direnv"]
          ++ addIf (config.home-manager.users.${user}.programs.taskwarrior.enable or false) [".local/share/task"]
          ++ addIf (config.home-manager.users.${user}.programs.zoxide.enable or false) [".local/share/zoxide"]
          ++ addIf (config.home-manager.users.${user}.services.syncthing.enable or false) [".local/state/syncthing"];
      in
        fold (curr: acc:
          acc
          // {
            ${curr} = {directories = userDirs curr;};
          })
        {}
        enabledUsers;
    };

    # for some reason *this* is what makes networkmanager not get screwed completely instead of the impermanence module
    # stolen from https://github.com/sioodmy/dotfiles/blob/2877b9bc15188994a3a4785a070c1fed3f643de9/system/core/impermanence.nix#L8
    systemd.tmpfiles.rules = [
      "L /var/lib/NetworkManager/secret_key - - - - /persist/var/lib/NetworkManager/secret_key"
      "L /var/lib/NetworkManager/seen-bssids - - - - /persist/var/lib/NetworkManager/seen-bssids"
      "L /var/lib/NetworkManager/timestamps - - - - /persist/var/lib/NetworkManager/timestamps"
    ];
    # Prioritise /nix/persist for boot to let impermanence set the environment up
    fileSystems."${cfg.persistDir}".neededForBoot = true;
  };
}
