{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkIf
    mkDefault
    mkMerge
    forEach
    ;
  mapList = lib.map;
  inherit
    (lib.strings)
    concatStringsSep
    normalizePath
    ;
  cfg = config.mnemosyne;
  persistPath = path: normalizePath "${cfg.persistDir}${path}";
  machineIdPath = persistPath "/etc/machine-id";
  mkMounts = dirs:
    dirs
    |> mapList (path: {
      "${path}" = {
        device = persistPath path;
        fsType = "none";
        options = cfg.mountOpts;
      };
    })
    |> mkMerge;

  # systemd-initrd mounts persisted storage under /sysroot.
  mkSourcePaths = root: dirs: dirs |> (dirs: forEach dirs (path: "mkdir -p ${root}${persistPath path}")) |> concatStringsSep "\n";
in {
  config = mkIf cfg.enable {
    mnemosyne.dirs = [
      "/etc/nixos"
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"
      "/var/lib/pipewire"
      "/etc/secrets"
    ];

    # Persist only host keys; mounting all of /etc/ssh would hide generated config.
    services.openssh.hostKeys = mkIf config.services.openssh.enable [
      {
        path = "${cfg.persistDir}/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        bits = 4096;
        path = "${cfg.persistDir}/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
      }
    ];

    # Create bind-mount sources in the systemd initrd before stage 2.
    boot.initrd.systemd.enable = mkDefault true;
    fileSystems = mkMounts cfg.dirs;
    # RequiresMountsFor resolves the persisted submount without guessing its unit name.
    # Write under /sysroot; ordering before sysroot.mount would deadlock.
    boot.initrd.systemd.services.make-source-of-persistent-dirs = {
      wantedBy = ["initrd-fs.target"];
      before = ["initrd-fs.target"];
      unitConfig = {
        DefaultDependencies = false;
        RequiresMountsFor = "/sysroot${cfg.persistDir}";
      };
      serviceConfig.Type = "oneshot";
      script = ''
        ${mkSourcePaths "/sysroot" cfg.dirs}

        mkdir -p /sysroot${cfg.persistDir}/etc /sysroot/etc
        if [ ! -s /sysroot${machineIdPath} ]; then
          uuid="$(cat /proc/sys/kernel/random/uuid)"
          printf '%s\n' "''${uuid//-/}" > /sysroot${machineIdPath}
          chmod 0444 /sysroot${machineIdPath}
        fi
        cp /sysroot${machineIdPath} /sysroot/etc/machine-id
      '';
    };

    # Preserve the current identity before the next boot starts from tmpfs.
    system.activationScripts.mnemosyne-machine-id = ''
      mkdir -p ${cfg.persistDir}/etc
      if [ ! -s ${machineIdPath} ] && [ -s /etc/machine-id ]; then
        cp /etc/machine-id ${machineIdPath}
        chmod 0444 ${machineIdPath}
      fi
    '';
  };
}
