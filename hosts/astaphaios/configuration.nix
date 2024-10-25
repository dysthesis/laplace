{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault;
  initrdSSHKeyPath = "/etc/secrets/initrd/ssh_host_ed25519_key";
in {
  config = {
    boot.kernelPackages = let
      inherit
        (pkgs.unstable)
        linuxPackagesFor
        linuxKernel
        ;
    in
      linuxPackagesFor linuxKernel.kernels.linux;

    services.qemuGuest.enable = true;
    networking = {
      useDHCP = mkDefault true;
      useNetworkd = mkDefault true;
    };
    boot.initrd = {
      luks.forceLuksSupportInInitrd = true;
      network = {
        enable = true;
        udhcpc.enable = true;
        flushBeforeStage2 = true;
        ssh = {
          enable = true;
          port = 2222;
          hostKeys = [initrdSSHKeyPath];
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOOeZRCxL7/q0UY7ZAAkM5HW6t8RULHu1b7BH3F/n2d2 demiurge@yaldabaoth"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPxBpd1Xyr16hfHFvd/AvOz8mLehUCI28QW3WNht4Xkn demiurge@adonaios"
          ];
        };
        postCommands = ''
          # Automatically ask for the password on SSH login
          echo 'cryptsetup-askpass || echo "Unlock was successful; exiting SSH session" && exit 1' >> /root/.profile
        '';
      };
    };

    # https://wiki.nixos.org/wiki/Install_NixOS_on_Hetzner_Online
    systemd.network = {
      enable = true;
      networks.default = {
        name = "en*"; # The name of the interface
        DHCP = "ipv4";
        address = [
          "65.21.245.118"
          "2a01:4f9:c012:d6d::/64"
        ];
        gateway = ["fe80::1"];
        linkConfig.RequiredForOnline = "routable";
      };
    };

    laplace = {
      hardware = {
        cpu = "none";
        gpu = "none";
      };

      bootloader = "grub";

      network = {
        bluetooth.enable = false;
        wifi.enable = false;
        dnscrypt-proxy.enable = true;
      };

      security = {
        privesc = "doas";
        apparmor.enable = true;
        polkit.enable = true;
        secure-boot.enable = false;
        firewall.enable = true;
      };

      users.abraxas = {
        enable = true;
        useHomeManager = true;
      };

      features = {
        ssh.enable = true;

        restic = {
          enable = true;
          paths = ["/nix/persist"];
          targets = ["b2:astaphaios"];
        };

        services = {
          miniflux.enable = true;
          traefik.enable = true;
          forgejo.enable = true;
          searxng.enable = true;
          openbooks.enable = true;
          caddy.enable = true;
          owntracks.enable = true;
          excalidraw.enable = true;
          calibre-web.enable = true;
          vikunja.enable = true;
          wallabag.enable = true;
          firefly-iii.enable = true;
        };

        nh = {
          enable = true;
          flakePath = "/home/abraxas/laplace";
        };

        impermanence.enable = true;
        virtualisation.enable = false;

        hardening = {
          kernel.enable = true;
          malloc.enable = true;
        };

        docs.enable = false;
      };
    };

    time.timeZone = "Australia/Sydney";
    i18n.defaultLocale = "en_AU.UTF-8";

    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-120n.psf.gz";
    };

    system.stateVersion = "24.11";
  };
}
