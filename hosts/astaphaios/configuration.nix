{pkgs, ...}: {
  config = {
    # https://wiki.nixos.org/wiki/Install_NixOS_on_Hetzner_Online
    systemd.network = {
      enable = true;
      networks.default = {
        name = "en*"; # The name of the interface
        DHCP = "ipv4";
        address = [
          # TODO: Replace the address with the one assigned to your machine
          "2a01:4f8:AAAA:BBBB::1/64"
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

      bootloader = "systemd-boot";

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
        nh = {
          enable = true;
          flakePath = "/home/sophia/laplace";
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
