{
  config,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  ddnsHost = "portunus.${fqdn}";
  headscaleHost = "headscale.${fqdn}";
  headscaleUpstream = "10.0.50.2:8080";
  # Forgejo on hephaestus, VLAN70. Same edge-TLS split as headscale: Caddy here
  # terminates TLS and reverse-proxies across the VLAN40->VLAN70 pinhole (OPNsense
  # must pass it). git.dysthesis.com is a CNAME to ddnsHost in Cloudflare, so it
  # follows the ddclient A record automatically — do NOT add it to ddclient.
  gitHost = "git.${fqdn}";
  gitUpstream = "10.0.70.2:8080";
  # Anubis (PoW anti-scraper gate) sits between Caddy and Forgejo. Loopback TCP
  # rather than the module's default unix socket: the socket lands in
  # /run/anubis owned by the anubis DynamicUser, and teaching caddy to connect
  # means group/socket-mode coupling for zero gain on a single-host hop.
  gitAnubis = "127.0.0.1:8923";
in {
  sops.secrets.cloudflare_ddns_token.sopsFile = ../../system/secrets/portunus.yaml;
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.40.1"];
    firewall.allowedTCPPorts = [80 443];
    # nftables backend so the beszel agent's scoped :45876 rule (extraInputRules)
    # actually applies — it is a silent no-op on the iptables backend. portunus
    # has no tailscale (which would flip this on), and no Docker, so set it here.
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.40.2/24";
      Gateway = "10.0.40.1";
      DNS = "10.0.40.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    harden = ["malloc" "kernel"];
    proxmox = {
      cores = 1;
      memory = 1024; # MiB, ballooning ceiling
      balloon = 512; # MiB, ballooning floor (caddy + ddclient + anubis; each is a small Go proc)
      diskSize = "20G";
    };
    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;
    services = {
      # SSH/pull: portunus is in the DMZ and cannot reach the tailnet hub, so the
      # hub dials IN instead. portunus listens on :45876, scoped to mimir only;
      # OPNsense must also pass VLAN20 (mimir 10.0.20.83) -> 10.0.40.2:45876. KEY
      # is the hub's PUBLIC key (same string as the WS env files), so no sops.
      beszel.agent = {
        enable = true;
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
        trustedHubs = ["10.0.20.83"];
      };
      caddy = {
        enable = true;
        virtualHosts = {
          ${headscaleHost}.extraConfig = ''
            reverse_proxy http://${headscaleUpstream}
          '';
          # Caddy imposes no request-body cap (unlike nginx's 1M), so large git
          # pushes over HTTPS pass through without extra config. Forgejo is
          # gated behind Anubis (below), which proxies on to hephaestus.
          # header_up is NOT optional: this caddy sends neither X-Real-Ip nor
          # X-Forwarded-For on its own (verified live), and Anubis hard-500s
          # ("maybeReverseProxy") without a resolvable client IP.
          ${gitHost}.extraConfig = ''
            reverse_proxy http://${gitAnubis} {
              header_up X-Real-Ip {client_ip}
              header_up X-Forwarded-For {client_ip}
            }
          '';
        };
      };
    };
  };

  # Anti-scraper gate for the public Forgejo UI: Caddy -> Anubis -> hephaestus.
  # The default bot rules only challenge browser-ish (Mozilla) user agents and
  # block known AI scrapers; git's UA ("git/2.x") matches neither, but pin an
  # explicit ALLOW so clone/push over HTTPS can never regress into an
  # interstitial if upstream's defaults change. The talos runner bypasses this
  # entirely (direct VLAN pinhole to hephaestus).
  services.anubis.instances.git = {
    settings = {
      BIND = gitAnubis;
      BIND_NETWORK = "tcp";
      TARGET = "http://${gitUpstream}";
      # Anubis rewrites X-Forwarded-For before proxying: it appends its own
      # remote (caddy's loopback, always stripped again) and by default strips
      # private addresses too — which would erase LAN clients and leave Forgejo
      # attributing them all to portunus. Keep private IPs in the chain.
      XFF_STRIP_PRIVATE = false;
    };
    policy.extraBots = [
      {
        name = "git-clients";
        user_agent_regex = "^git/";
        action = "ALLOW";
      }
    ];
  };

  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    server = "api.cloudflare.com/client/v4";
    username = "token";
    passwordFile = config.sops.secrets.cloudflare_ddns_token.path;
    zone = fqdn;
    # headscaleHost is a CNAME to ddnsHost in Cloudflare, so it follows this
    # A record automatically; managing it here would clash with the CNAME.
    domains = [ddnsHost];
    usev6 = "";
    interval = "5min";
    extraConfig = ''
      ttl=1
    '';
  };

  # Work around nixpkgs#350408: DynamicUser sometimes is not visible to NSS
  # when ddclient's ExecStartPre resolves $USER for install --owner.
  users.groups.ddclient = {};
  users.users.ddclient = {
    isSystemUser = true;
    group = "ddclient";
  };
  systemd.services.ddclient.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "ddclient";
    Group = "ddclient";
  };

  mnemosyne.dirs = [
    "/var/lib/acme"
    "/var/lib/caddy"
    "/var/lib/ddclient"
  ];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
