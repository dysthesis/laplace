# Proxmox guests use a tmpfs root and persistent Btrfs /nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkDefault mkForce elem mkOption optionalAttrs types;
  enabled = elem "proxmox" config.laplace.profiles;
  cfg = config.laplace.proxmox;
  hostName = config.networking.hostName;
  keys = import ../../users/keys.nix;
  rootTmpfsSize =
    if cfg.balloon != null && cfg.balloon > 0
    then "${toString (builtins.div (cfg.balloon * 3) 4)}M"
    else "50%";
  btrfsMountOptions = [
    "defaults"
    "noatime"
    "compress=zstd"
    "space_cache=v2"
    "discard=async"
  ];
in {
  options.laplace.proxmox = {
    cores = mkOption {
      type = types.ints.positive;
      default = 2;
      description = "vCPU count baked into the guest's qemu-server.conf.";
    };
    memory = mkOption {
      type = types.ints.positive;
      default = 2048;
      description = "RAM in MiB baked into the guest's qemu-server.conf. With ballooning this is the maximum.";
    };
    balloon = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      description = ''
        Minimum RAM in MiB for ballooning (the qemu-server `balloon` property).
        null omits the line, so Proxmox keeps the guest pinned at `memory`. A
        value below `memory` lets the host reclaim down to it under pressure
        (the guest boots at `memory` and the balloon inflates as needed); 0
        disables the balloon device entirely.
      '';
    };
    bridge = mkOption {
      type = types.str;
      default = "vmbr0";
      description = "Proxmox network bridge attached to net0.";
    };
    macAddress = mkOption {
      type = types.str;
      default = "00:00:00:00:00:00";
      description = "net0 MAC address. Leave as zeros to let Proxmox assign one.";
    };
    diskSize = mkOption {
      type = types.strMatching "[0-9]+[KMGTP]?";
      default = "16G";
      description = "Virtual disk size of the built image (disko imageSize).";
    };
  };

  config = mkIf enabled {
    # Ballooning floor can't exceed the ceiling, or Proxmox rejects the conf.
    assertions = [
      {
        assertion = cfg.balloon == null || cfg.balloon <= cfg.memory;
        message = "laplace.proxmox.balloon (${toString cfg.balloon}) must be <= laplace.proxmox.memory (${toString cfg.memory}) on ${hostName}.";
      }
    ];

    # mkDefault lets a guest replace the admin list without duplication.
    laplace.users = mkDefault ["archon"];

    # SeaBIOS uses GRUB on disko's EF02 partition; no EFI variables.
    laplace.bootloader = mkDefault "grub";

    boot = {
      loader.efi.canTouchEfiVariables = mkForce false;

      # Inline guest options so cfg.enabled gates all of them.
      initrd = {
        availableKernelModules = [
          "virtio_pci"
          "virtio_blk"
          "virtio_scsi"
          "virtio_net"
          "uas"
          "sd_mod"
        ];
        kernelModules = [
          "virtio_balloon"
          "virtio_console"
          "virtio_rng"
        ];
      };
      # Serial console so `qm terminal` works; keep tty1 for the noVNC console.
      kernelParams = [
        "console=ttyS0,115200"
        "console=tty1"
      ];
    };
    # Root is already tmpfs; a second /tmp tmpfs would bypass rootTmpfsSize.
    boot.tmp.useTmpfs = mkForce false;

    services = {
      qemuGuest.enable = true;

      # The volatile journal consumes RAM; cap it independent of guest size.
      # Use SystemMaxUse if /var/log/journal becomes persistent.
      journald.extraConfig = "RuntimeMaxUse=32M";

      # Kill bursty offenders before a ballooned guest stalls in memory pressure.
      earlyoom.enable = mkDefault true;

      openssh = {
        # Keep sshd resident; socket activation can lose its listener during failed switches.
        startWhenNeeded = mkDefault false;

        # Permit key-only root deployment from VLAN20; keep interactive doas prompts.
        extraConfig = ''
          Match Address 10.0.20.0/24
            PermitRootLogin prohibit-password
        '';

        # Close global SSH before adding the VLAN20-only rule.
        # Keep the default open on iptables, where extraInputRules cannot replace it.
        openFirewall = mkIf config.networking.nftables.enable (mkForce false);
      };
    };

    # Limit SSH to VLAN20; DMZ neighbours must not reach guest administration.
    networking.firewall.extraInputRules = mkIf config.networking.nftables.enable ''
      ip saddr 10.0.20.0/24 tcp dport 22 accept
    '';

    nix.settings.trusted-users = ["root" "@wheel"];
    users.users.root.openssh.authorizedKeys.keys = [
      keys.phobos
      keys.deimos
    ];

    mnemosyne.enable = true;
    fileSystems."/nix/persist".neededForBoot = true;
    disko.devices = {
      disk.main = {
        device = "/dev/vda";
        type = "disk";
        imageSize = cfg.diskSize; # disko does not derive this from partitions
        content = {
          type = "gpt";
          partitions = {
            bios = {
              size = "1M";
              type = "EF02"; # BIOS boot partition for grub on GPT
            };
            boot = {
              size = "1G";
              content = {
                type = "filesystem";
                format = "ext4"; # grub reads /boot directly; keep it simple
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"];
                subvolumes = {
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = btrfsMountOptions;
                  };
                  "@persist" = {
                    mountpoint = "/nix/persist";
                    mountOptions = btrfsMountOptions;
                  };
                };
              };
            };
          };
        };
      };
      nodev."/" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=${rootTmpfsSize}"
          "mode=755"
          "defaults"
        ];
      };
    };

    # Repack the disko image as a Proxmox VMA.
    system.build.proxmoxVMA = pkgs.proxmox-vma {
      rawImage = config.system.build.diskoImages;
      baseName = "vzdump-qemu-${hostName}";
      qemuConf =
        {
          boot = "order=virtio0";
          scsihw = "virtio-scsi-single";
          virtio0 = "local-lvm:vm-9999-disk-0";
          ostype = "l26";
          inherit (cfg) cores memory;
          bios = "seabios";
          name = hostName;
          net0 = "virtio=${cfg.macAddress},bridge=${cfg.bridge}";
          serial0 = "socket";
          agent = 1;
        }
        // optionalAttrs (cfg.balloon != null) {inherit (cfg) balloon;};
    };
  };
}
