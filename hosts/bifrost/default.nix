{
  config,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  subdomain = "headscale";
  horosTailnetIp = "100.64.0.10";
in {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.40.1"];
    hosts."10.0.40.2" = ["headscale.dysthesis.com"];
    # Only the Headscale coordination port is served on the LAN: portunus
    # terminates TLS for headscale.dysthesis.com and reverse-proxies to
    # 10.0.40.3:8080 over VLAN40, so that hop is plaintext within the trusted
    # infra segment by design. 80/443 were dead (no web server runs here) and
    # Headplane is reachable only from horos over tailscale0.
    firewall = {
      allowedTCPPorts = [
        config.laplace.services.headscale.port
      ];

      # Do not trust all tailnet peers on this host: Headplane is a management UI.
      # Only horos may reach it over tailscale0; horos then serves
      # headplane.dysthesis.com to the rest of the tailnet.
      trustedInterfaces = lib.mkForce [];
      extraInputRules = ''
        iifname "${config.services.tailscale.interfaceName}" ip saddr ${horosTailnetIp} tcp dport ${toString config.laplace.services.headplane.port} accept
      '';
    };
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
          horos = horosTailnetIp;
        in [
          {
            name = "headplane.${fqdn}";
            type = "A";
            value = horos;
          }
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
          {
            name = "linkwarden.${fqdn}";
            type = "A";
            value = horos;
          }
        ];
      };
    };

    services.headplane = {
      enable = true;
      fqdn = "headplane.${fqdn}";
      # Horos proxies this over the tailnet. The port is not opened globally;
      # host firewall allows only horos's tailnet IP to connect.
      address = "0.0.0.0";
      openFirewall = false;
    };

    services.tailscale.enable = true;
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
