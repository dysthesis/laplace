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
      balloon = 384; # MiB, ballooning floor (caddy + tailscaled; 384 leaves two Go daemons margin)
      diskSize = "15G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

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
          # immich is intentionally NOT proxied here: it is ACL-gated per-cohort at
          # its mneme backend (immich.dysthesis.com resolves straight to mneme), which
          # a shared :443 Caddy listener cannot isolate. See hosts/bifrost acl groups.
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

  # Minecraft (loki) ingress. The Java protocol is raw TCP, not HTTP, so it can't
  # ride a Caddy reverse_proxy (and needs no TLS). A systemd socket proxy - shipped
  # with systemd, no extra package - accepts mc.dysthesis.com:25565 on the tailnet
  # and forwards to loki's node. Only tailscale0 is trusted
  # (laplace.services.tailscale), so the LAN never reaches 25565; mc.dysthesis.com
  # resolves to horos's tailnet IP via the bifrost extra_record. The upstream is
  # loki's tailnet name (its MC port is closed to the LAN), so this rides WireGuard.
  systemd.sockets.minecraft-loki = {
    description = "Minecraft ingress socket (forwarded to loki)";
    wantedBy = ["sockets.target"];
    socketConfig.ListenStream = "25565";
  };
  systemd.services.minecraft-loki = {
    description = "Minecraft TCP proxy to loki over the tailnet";
    requires = ["minecraft-loki.socket" "tailscaled.service"];
    after = ["minecraft-loki.socket" "tailscaled.service"];
    serviceConfig = {
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd loki.tailnet.${fqdn}:25565";
      DynamicUser = true; # pure userspace TCP relay - no fs/privilege surface
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"]; # AF_UNIX: sd_notify + resolved
    };
  };

  mnemosyne.dirs = [
    "/var/lib/caddy" # ACME account + issued certs
  ];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
