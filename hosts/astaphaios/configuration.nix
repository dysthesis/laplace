{
  lib,
  pkgs,
  ...
}: {
  config = {
    networking.useNetworkd = lib.mkDefault true;
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
        useHomeManager = false;
      };

      features = {
        ssh.enable = true;
        miniflux.enable = true;
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
