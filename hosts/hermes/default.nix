{pkgs, ...}: {
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 2048; # MiB, ballooning ceiling
      balloon = 384; # MiB, ballooning floor (AdGuard idles ~150 MiB; headroom for filter lists/query log)
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

      # AdGuard's own TLS frontend (no central horos proxy). adguard.dysthesis.com
      # resolves to hermes now and is reached over the tailnet (admin-only via ACL).
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false; # tailnet-only; :443 reached over tailscale0
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/cloudflare.yaml;
          proxies."adguard.dysthesis.com" = "localhost:80";
        };
      };
    };
  };

  # AdGuard owns 0.0.0.0:80 (its web UI); stop Caddy from also grabbing :80 for
  # HTTP->HTTPS redirects. DNS-01 needs no :80, so Caddy listens on :443 only.
  services.caddy.globalConfig = "auto_https disable_redirects";
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
