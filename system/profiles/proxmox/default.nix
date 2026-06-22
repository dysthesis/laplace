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
  inherit (lib) mkIf mkDefault mkForce elem mkOption optionalAttrs types;
  enabled = elem "proxmox" config.laplace.profiles;
  cfg = config.laplace.proxmox;
  hostName = config.networking.hostName;
  rootTmpfsSize =
    if cfg.balloon != null
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
    # `/` is already tmpfs (RAM), so the global boot.tmp.useTmpfs (a *second*
    # tmpfs for /tmp, default 50% of RAM) is redundant here and doubles the
    # RAM-backed-write surface. Force it off so /tmp rides the root tmpfs and is
    # bounded by rootTmpfsSize, not its own half-of-RAM cap.
    boot.tmp.useTmpfs = mkForce false;

    services = {
      qemuGuest.enable = true;

      # The journal lives on the tmpfs root: mnemosyne does not persist /var/log,
      # so with no /var/log/journal directory journald keeps logs in /run (RAM).
      # The default volatile cap scales with /run (~10% of RAM), which on the
      # larger guests is tens of MiB of RAM spent on logs. Pin a deterministic
      # ceiling instead. (If /var/log/journal is ever persisted to btrfs, switch
      # this to SystemMaxUse, which governs the persistent store.)
      journald.extraConfig = "RuntimeMaxUse=32M";

      # Backstop for the tightened ballooning floors: when the host reclaims a
      # guest down near its floor and a burst (git gc, Chromium archive, ML run,
      # a /tmp filler) pushes it over, earlyoom kills the offender early instead
      # of letting the guest stall in a livelock. It watches free RAM *and* zram
      # swap, so balloon deflation alone (reclaimable cache) does not trip it.
      earlyoom.enable = mkDefault true;

      openssh = {
        # sshd MUST stay resident, NOT socket-activated, on these headless guests.
        # A switch-to-configuration hang (the STC job-wait loops have no timeout and
        # spin forever if the systemd dbus transport drops mid-switch - see the
        # `timeout`-wrapped STC overlay in nix/overlays/stc-timeout.nix) or memory
        # pressure can leave sshd.socket with no listener, stranding the guest with
        # no recovery path but the Proxmox console. A resident sshd.service survives
        # both. The few MiB `startWhenNeeded` saved are not worth losing remote
        # access to a headless VM - that trade cost mimir/horos/mneme a deploy.
        startWhenNeeded = mkDefault false;

        # Central push-deploy connects as root over the LAN and runs
        # switch-to-configuration directly, so the closure activates without
        # interactive escalation. Root SSH stays disabled globally
        # (system/default.nix forces PermitRootLogin "no"); this Match re-permits it
        # *key-only* from the two infra VLANs where the workstations live. doas keeps
        # prompting for interactive use - unweakened.
        extraConfig = ''
          Match Address 10.0.20.0/24,10.0.40.0/24
            PermitRootLogin prohibit-password
        '';

        # The global default (system/default.nix) opens :22 on every interface, so
        # a popped node can reach sshd on every peer over the tailnet. Close that on
        # the fleet and let the scoped rule below be the sole :22 opening. Gated on
        # nftables: extraInputRules silently evaporates on the iptables backend, so
        # without nftables this pair would drop :22 entirely (lockout) — an iptables
        # guest keeps the open default instead.
        openFirewall = mkIf config.networking.nftables.enable (mkForce false);
      };
    };

    # Scope :22 to the VLAN20 admin/deploy source only. VLAN20-only deliberately
    # excludes the DMZ (VLAN40): a sacrificial DMZ neighbour must not reach a
    # guest's sshd. Generalises the former bifrost-only F7 scoping to every
    # nftables guest. (Merges with any host's own extraInputRules — it is lines.)
    networking.firewall.extraInputRules = mkIf config.networking.nftables.enable ''
      ip saddr 10.0.20.0/24 tcp dport 22 accept
    '';

    # Receive closures pushed by the central deployer (Colmena, `just deploy`).
    nix.settings.trusted-users = ["root" "@wheel"];
    users.users.root.openssh.authorizedKeys.keys = [
      # Workstation deploy keys (mirror archon's; rotate together).
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoKu8wF8Ts5xlCcKBQ8zRU7A4NsujnhzfsGfaP62kf2 demiurge@phobos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUPaVrhCJ8fDKDYCcIeICgCv6W+0GdGmMDrngIg1oKg demiurge@deimos"
    ];

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
          "size=${rootTmpfsSize}"
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
