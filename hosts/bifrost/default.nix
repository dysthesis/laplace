{
  config,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  subdomain = "headscale";
in {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.40.1"];
    # Only the Headscale coordination port is served on the LAN: portunus
    # terminates TLS for headscale.dysthesis.com and reverse-proxies to
    # 10.0.40.3:8080 over VLAN40, so that hop is plaintext within the trusted
    # infra segment by design. 80/443 were dead (no web server runs here) and
    # Headplane is now bound to loopback.
    firewall.allowedTCPPorts = [
      config.laplace.services.headscale.port
    ];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.40.3/24";
      Gateway = "10.0.40.1";
      DNS = "10.0.40.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 2048; # MiB
      diskSize = "64G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    nh = {
      enable = true;
      flakePath = "/etc/config";
    };

    services.headscale = {
      enable = true;
      fqdn = "${subdomain}.${fqdn}";
      baseDomain = "tailnet.${fqdn}";

      # Push the AdGuard instance on hermes as the tailnet's resolver. Must be
      # hermes's *tailnet* IP, not its LAN 10.0.20.82: tailnet clients live on
      # other subnets and only reach AdGuard over tailscale0 (where AdGuard
      # already binds 0.0.0.0:53). override_local_dns sends all tailnet DNS
      # through it for filtering everywhere.
      settings.dns = {
        override_local_dns = true;
        nameservers.global = ["100.64.0.5"];

        # MagicDNS records for the apps behind the central Caddy on horos. All
        # the service names point at horos's *tailnet* IP (100.x), not its LAN
        # address, so the traffic rides WireGuard; horos then proxies each to the
        # app's own node over the tailnet. The names are bare *.dysthesis.com
        # with no public Cloudflare A record, so they resolve only here - the
        # tailscale client answers these explicit records and off-tailnet gets
        # NXDOMAIN from public DNS.
        extra_records = let
          horos = "100.64.0.10";
        in [
          {
            name = "immich.${fqdn}";
            type = "A";
            value = horos;
          }
          {
            name = "adguard.${fqdn}";
            type = "A";
            value = horos;
          }
          {
            name = "miniflux.${fqdn}";
            type = "A";
            value = horos;
          }
          {
            name = "silverbullet.${fqdn}";
            type = "A";
            value = horos;
          }
        ];
      };
    };

    services.headplane = {
      enable = true;
      fqdn = "headplane.${fqdn}";
      # Headplane mints pre-auth keys and manages nodes; with no OIDC and only
      # api-key login it must not sit on the LAN. Bind loopback and reach it via
      # an SSH tunnel: ssh -L 3000:localhost:3000 bifrost
      address = "127.0.0.1";
      openFirewall = false;
    };
  };

  mnemosyne.dirs = ["/etc/config"];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
