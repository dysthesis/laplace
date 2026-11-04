{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  inherit (lib.strings) normalizePath;
  cfg = config.mnemosyne;
  persistPath = path: normalizePath "${cfg.persistDir}${path}";
  machineIdPath = persistPath "/etc/machine-id";
in {
  config = mkIf cfg.enable {
    mnemosyne.dirs = [
      "/etc/nixos"
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"
      "/var/lib/pipewire"
      "/etc/secrets"
    ];

    # Persist only host keys. A mount over /etc/ssh hides the generated configuration.
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
    fileSystems = lib.genAttrs cfg.dirs (path: {
      device = persistPath path;
      fsType = "none";
      options = cfg.mountOpts;
    });
    # RequiresMountsFor resolves the unit name of the persistent submount.
    # Write under /sysroot. Do not order this service before sysroot.mount because that causes a deadlock.
    boot.initrd.systemd.services.make-source-of-persistent-dirs = {
      wantedBy = ["initrd-fs.target"];
      before = ["initrd-fs.target"];
      unitConfig = {
        DefaultDependencies = false;
        RequiresMountsFor = "/sysroot${cfg.persistDir}";
      };
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p ${lib.escapeShellArgs (map (path: "/sysroot${persistPath path}") cfg.dirs)} \
          /sysroot${cfg.persistDir}/etc /sysroot/etc
        if [ ! -s /sysroot${machineIdPath} ]; then
          uuid="$(cat /proc/sys/kernel/random/uuid)"
          printf '%s\n' "''${uuid//-/}" > /sysroot${machineIdPath}
          chmod 0444 /sysroot${machineIdPath}
        fi
        cp /sysroot${machineIdPath} /sysroot/etc/machine-id
      '';
    };

    # Keep the machine identity before the next boot starts from tmpfs.
    system.activationScripts.mnemosyne-machine-id = ''
      mkdir -p ${cfg.persistDir}/etc
      if [ ! -s ${machineIdPath} ] && [ -s /etc/machine-id ]; then
        cp /etc/machine-id ${machineIdPath}
        chmod 0444 ${machineIdPath}
      fi
    '';
  };
}
