{pkgs, ...}: {
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 2048; # MiB, ballooning ceiling
      balloon = 512; # MiB, ballooning floor (AdGuard idles ~150 MiB)
      diskSize = "64G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
      polkit.enable = true;
      firewall.enable = true;
      fail2ban.enable = true;
    };

    zram.enable = true;

    services = {
      adguardhome.enable = true;
      tailscale = {
        enable = true;
        # AdGuard owns 0.0.0.0:53 here; keep tailscaled from pulling in
        # systemd-resolved and squatting tcp/53 via its loopback stubs.
        denyDNS = true;
      };
    };
  };
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.82/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
