# Profile for NixOS guests running as Proxmox VMs.
#
# Owns the *runtime* half of a guest (filesystems, bootloader, serial console,
# virtio, qemuGuest) AND the image-build half (disko layout + a VMA artifact),
# from a single source of truth, so a guest's host module only declares its
# services and a little sizing under `laplace.proxmox.*`.
#
# Impermanence is real here: `/` is tmpfs, with `/nix` and `/nix/persist` on a
# btrfs disk (the deimos pattern, minus LUKS/@home/@swap and using BIOS boot).
# State is kept declaratively via `mnemosyne` (see [[mnemosyne-persist-mount-coupling]]:
# `/nix/persist` is a real `neededForBoot` mount, which `mnemosyne` requires).
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkDefault mkForce elem mkOption types;
  enabled = elem "proxmox" config.laplace.profiles;
  cfg = config.laplace.proxmox;
  hostName = config.networking.hostName;
  btrfsMountOptions = [
    "defaults"
    "noatime"
    "compress=zstd"
    "space_cache=v2"
    "discard=async"
  ];
in {
  # Declared unconditionally: the selector imports this module for every host, so
  # the option must exist even where the profile is disabled. Only `config` below
  # is gated.
  options.laplace.proxmox = {
    cores = mkOption {
      type = types.ints.positive;
      default = 2;
      description = "vCPU count baked into the guest's qemu-server.conf.";
    };
    memory = mkOption {
      type = types.ints.positive;
      default = 2048;
      description = "RAM in MiB baked into the guest's qemu-server.conf.";
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
    # Default admin identity. mkDefault so a host that sets `laplace.users`
    # replaces it wholesale (rather than concatenating a duplicate); a guest with
    # a different admin just declares its own list.
    laplace.users = mkDefault ["archon"];

    # seabios + grub (legacy). disko's EF02 partition sets boot.loader.grub.devices
    # to /dev/vda, so we only pick the bootloader and disable EFI vars (no ESP).
    laplace.bootloader = mkDefault "grub";

    boot = {
      loader.efi.canTouchEfiVariables = mkForce false;

      # virtio guest essentials, inlined rather than importing the upstream
      # qemu-guest profile so the whole module stays gated behind `enabled`.
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
    services.qemuGuest.enable = true;

    # Allow remote `nixos-rebuild`/`nh` from the workstations.
    nix.settings.trusted-users = ["root" "@wheel"];

    # Real impermanence: tmpfs root, btrfs-backed persistent /nix + /nix/persist.
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
          "size=50%"
          "mode=755"
          "defaults"
        ];
      };
    };

    # Proxmox VMA artifact: disko raw image repacked via PVE's vma tool.
    # Build with `nix build .#nixosConfigurations.<host>.config.system.build.proxmoxVMA`.
    system.build.proxmoxVMA = pkgs.proxmox-vma {
      rawImage = config.system.build.diskoImages;
      baseName = "vzdump-qemu-${hostName}";
      qemuConf = {
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
      };
    };
  };
}
