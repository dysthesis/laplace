{
  config,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";

  # DNS-01 via Cloudflare, repeated per site. `resolvers 1.1.1.1` sends the
  # challenge lookups straight to a public resolver, bypassing the tailnet DNS;
  # without this whole block Caddy falls back to HTTP-01/TLS-ALPN, which can't be
  # validated for a name that only resolves on the tailnet.
  tls = ''
    tls {
      dns cloudflare {env.CF_API_TOKEN}
      resolvers 1.1.1.1
    }
  '';
  # upstream is the app's MagicDNS node name + the port it actually binds.
  proxy = upstream: ''
    ${tls}
    reverse_proxy ${upstream}
  '';
in {
  sops = {
    # Cloudflare API token with Zone:DNS:Edit on dysthesis.com, for the DNS-01
    # challenge. Reuse the token mimir used (and retire mimir's copy), or mint a
    # fresh one. Lives in horos's own sops file (mirrors portunus/mimir).
    secrets.cloudflare_api_key.sopsFile = ../../system/secrets/horos.yaml;

    # Render the token into an EnvironmentFile so Caddy reads {env.CF_API_TOKEN}.
    templates."caddy-cloudflare.env".content = ''
      CF_API_TOKEN=${config.sops.placeholder.cloudflare_api_key}
    '';
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  # VLAN 20, alongside the app hosts (mneme .81, hermes .82, mimir .83). .84 is
  # the next free host at time of writing; confirm against your IPAM before
  # deploying.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.85/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 1024; # MiB, ballooning ceiling
      balloon = 512; # MiB, ballooning floor
      diskSize = "15G";
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

    services = {
      # Needed both to reach the upstreams over WireGuard and so clients reach
      # this proxy (the *.dysthesis.com names resolve to its tailnet IP).
      tailscale.enable = true;

      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";

        # One site per app. Each gets its own DNS-01 cert and proxies to the
        # app's node name over the tailnet. Adding an app = one more line here
        # plus one extra_record on bifrost.
        virtualHosts = {
          "headplane.${fqdn}".extraConfig = proxy "bifrost.tailnet.${fqdn}:3000";
          "immich.${fqdn}".extraConfig = proxy "mneme.tailnet.${fqdn}:2283";
          # AdGuard's setup wizard moved its web UI off the 3000 default onto 80.
          "adguard.${fqdn}".extraConfig = proxy "hermes.tailnet.${fqdn}:80";
          "miniflux.${fqdn}".extraConfig = proxy "mimir.tailnet.${fqdn}:8087";
          "silverbullet.${fqdn}".extraConfig = proxy "mimir.tailnet.${fqdn}:8101";
        };
      };
    };
  };

  # The stock Caddy has no `dns cloudflare`; bake the plugin in. Same plugin +
  # vendored-deps FOD hash as mimir; bump both together when the version changes.
  services.caddy.package = pkgs.caddy.withPlugins {
    plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
    hash = "sha256-8yZDrejNKsaUnUaTUFYbarWNmxafqp2z2rWo+XRsxV8=";
  };

  # Feed the sops-rendered token into Caddy's process environment.
  systemd.services.caddy.serviceConfig.EnvironmentFile =
    config.sops.templates."caddy-cloudflare.env".path;

  mnemosyne.dirs = [
    "/etc/config" # on-disk flake clone for remote rebuilds
    "/var/lib/caddy" # ACME account + issued certs
  ];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
