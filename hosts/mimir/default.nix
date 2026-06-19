# Miniflux + SilverBullet host, running as a Proxmox guest. Generic VM concerns
# (disk, impermanence, bootloader, virtio, qemuGuest, the archon admin user, the
# VMA artifact) live in the `proxmox` profile; this module only declares what is
# specific to this guest: the two apps and an internal Caddy that fronts them.
#
# TLS: the service names resolve only inside the tailnet (Headscale extra_records
# on bifrost point them at mimir's 100.x), so HTTP-01/TLS-ALPN can't validate
# them. Caddy uses ACME DNS-01 against Cloudflare (which serves dysthesis.com
# publicly) for a real, publicly-trusted wildcard cert on a privately-resolving
# name. That needs the cloudflare DNS plugin baked into the binary + an explicit
# `tls { dns cloudflare ... }` directive, or issuance silently hangs.
{
  config,
  lib,
  pkgs,
  ...
}: let
  baseDomain = "tailnet.dysthesis.com";
  minifluxHost = "miniflux.${baseDomain}";
  silverbulletHost = "silverbullet.${baseDomain}";

  # Upstreams are the actual addresses the service modules bind, NOT the 8080/3000
  # the spec guessed: miniflux LISTEN_ADDR is 127.0.0.1:8087, silverbullet 8101.
  minifluxUpstream = "127.0.0.1:8087";
  silverbulletUpstream = "127.0.0.1:8101";
in {
  # Cloudflare API token with Zone:DNS:Edit on dysthesis.com, for the DNS-01
  # challenge. Lives in mimir's own sops file (mirrors portunus's pattern).
  sops.secrets.cloudflare_api_key.sopsFile = ../../system/secrets/mimir.yaml;

  # Render the token into an EnvironmentFile so Caddy can read {env.CF_API_TOKEN}.
  sops.templates."caddy-cloudflare.env".content = ''
    CF_API_TOKEN=${config.sops.placeholder.cloudflare_api_key}
  '';

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  # VLAN 20, same segment as mneme/hermes/charon. .83 is the first free host in
  # that block at time of writing; confirm against your IPAM before deploying.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.83/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 2;
      memory = 2048; # MiB
      diskSize = "32G";
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
      tailscale.enable = true;
      miniflux.enable = true;
      silverbullet.enable = true;

      caddy = {
        enable = true;
        email = "dysthesis@gmail.com";

        # One wildcard site, DNS-01 issued, routed by Host. The explicit `tls`
        # block forces the DNS challenge; without it Caddy falls back to
        # HTTP-01/TLS-ALPN, which can't be validated for a tailnet-only name.
        virtualHosts."*.${baseDomain}".extraConfig = ''
          tls {
            dns cloudflare {env.CF_API_TOKEN}
            resolvers 1.1.1.1
          }

          @miniflux host ${minifluxHost}
          handle @miniflux {
            reverse_proxy ${minifluxUpstream}
          }

          @silverbullet host ${silverbulletHost}
          handle @silverbullet {
            reverse_proxy ${silverbulletUpstream}
          }

          handle {
            abort
          }
        '';
      };
    };
  };

  # The stock Caddy has no `dns cloudflare`; bake the plugin in. Hash is the
  # vendored-deps FOD hash; bump it whenever the plugin version changes.
  services.caddy.package = pkgs.caddy.withPlugins {
    plugins = ["github.com/caddy-dns/cloudflare@v0.2.1"];
    hash = "sha256-I0FjQOfFaGlOEJlQECmYNBKjIY4CIg5aCCQ/ORmnrSU=";
  };

  # Feed the sops-rendered token into Caddy's process environment.
  systemd.services.caddy.serviceConfig.EnvironmentFile =
    config.sops.templates."caddy-cloudflare.env".path;

  # Miniflux bakes BASE_URL into absolute links + cookie scope, so it must match
  # the public origin, not the module's bare-localhost default. Only mimir runs
  # miniflux, so override it here rather than parameterising the shared module.
  services.miniflux.config.BASE_URL = lib.mkForce "https://${minifluxHost}";

  mnemosyne.dirs = [
    "/etc/config" # on-disk flake clone for remote rebuilds
    "/var/lib/caddy" # ACME account + issued certs
  ];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
