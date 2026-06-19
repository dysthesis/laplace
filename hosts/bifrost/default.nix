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
    firewall.allowedTCPPorts = [
      80
      443
      config.laplace.services.headplane.port
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

        # MagicDNS records for the apps behind mimir's internal Caddy. Point at
        # mimir's *tailnet* IP (100.x), not its 10.0.20.83 LAN address, so the
        # traffic rides WireGuard. These FQDNs sit under base_domain, so the
        # Tailscale client answers them locally and never forwards to AdGuard,
        # even with override_local_dns on.
        extra_records = let
          mimir = "100.64.0.8"; # TODO: mimir's tailnet IP, once it has joined
        in [
          {
            name = "miniflux.tailnet.${fqdn}";
            type = "A";
            value = mimir;
          }
          {
            name = "silverbullet.tailnet.${fqdn}";
            type = "A";
            value = mimir;
          }
        ];
      };
    };

    services.headplane = {
      enable = true;
      fqdn = "headplane.${fqdn}";
    };
  };

  mnemosyne.dirs = ["/etc/config"];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
