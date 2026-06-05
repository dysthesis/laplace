{
  pkgs,
  config,
  ...
}: {
  config = {
    # boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod_latest;
    laplace = {
      bootloader = "systemd-boot";

      security = {
        privesc = "doas";
        apparmor.enable = true;
        polkit.enable = true;
        firewall.enable = true;
        fail2ban.enable = true;
      };

      impermanence.enable = true;
      zram.enable = true;

      nh = {
        enable = true;
        flakePath = "/etc/config";
      };
      services.forgejo.enable = true;
    };

    environment.systemPackages = with pkgs; [
      vim # for emergencies
      git # for pulling Nix flakes
      python3
    ];

    image.modules.proxmox.proxmox = {
      cloudInit.enable = false;
      qemuConf.bios = "ovmf";
      qemuConf.net0 = "virtio=00:00:00:00:00:00,bridge=vmbr0";
    };

    users.users.archon = let
      ifExists = groups:
        builtins.filter
        (group: builtins.hasAttr group config.users.groups)
        groups;
    in {
      description = "Archon";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoKu8wF8Ts5xlCcKBQ8zRU7A4NsujnhzfsGfaP62kf2 demiurge@phobos"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUPaVrhCJ8fDKDYCcIeICgCv6W+0GdGmMDrngIg1oKg demiurge@deimos"
      ];
      extraGroups =
        [
          "wheel"
          "video"
          "audio"
          "input"
          "nix"
          "networkmanager"
        ]
        ++ ifExists [
          "network"
          "docker"
          "podman"
          "libvirt"
          "render"
          "ollama"
        ];
    };

    mnemosyne = {
      enable = true;
      dirs = [
        "/etc/nixos"
        "/etc/NetworkManager/system-connections"
        "/etc/secrets"
        "/var/lib/bluetooth"
        "/var/lib/pipewire"
        "/etc/config"
        config.laplace.services.forgejo.stateDir
      ];
    };

    services.openssh.hostKeys = [
      {
        path = "/nix/persist/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
      {
        path = "/nix/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    services.qemuGuest.enable = true;
    nix.settings.trusted-users = ["root" "@wheel"]; # Allow remote updates
  };
}
