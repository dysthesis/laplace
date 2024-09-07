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
    then [content]
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
          "/etc/ssh"
          # Sops stuff
          "/etc/secrets"
          "/etc/NetworkManager/system-connections"
        ]
        ++ addIf config.laplace.features.virtualisation.enable "/var/lib/libvirt"
        ++ addIf config.laplace.network.bluetooth.enable "/var/lib/bluetooth"
        ++ addIf config.laplace.security.secure-boot.enable "/etc/secureboot";

      files =
        ["/etc/machine-id"]
        ++ addIf config.laplace.network.dnscrypt-proxy.enable "/etc/dnscrypt-proxy/blocked-names.txt";

      users = let
        enabledUsers =
          attrNames
          (filterAttrs
            (_name: value: value.enable)
            config.laplace.users);

        userDirs = [
          "Documents"
          "Downloads"
          "Music"
          "Pictures"
          "Sync"
          ".mozilla"
          ".password-store"
          ".cache/swww"
          ".config/signal"
          ".config/vesktop"
          ".local/state/syncthing"
          ".local/share/direnv"
          ".local/share/task"
          ".local/share/atuin"
          ".local/share/zoxide"
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
        ];
      in
        fold (curr: acc:
          acc
          // {
            ${curr} = {directories = userDirs;};
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
