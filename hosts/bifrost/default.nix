{
  config,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  subdomain = "headscale";
  # Addresses come from the fleet-wide SSOT (system/tailnet); this host only
  # references the four nodes it fronts.
  inherit (config.laplace.tailnet) nodes;
  adguardTailnetIp = nodes.hermes.ip; # AdGuard (also the tailnet resolver)
  mnemeTailnetIp = nodes.mneme.ip; # immich
  mimirTailnetIp = nodes.mimir.ip; # miniflux + silverbullet + radicale
  lokiTailnetIp = nodes.loki.ip; # minecraft
in {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.50.1"];
    hosts."10.0.40.2" = ["headscale.dysthesis.com"];
    # nftables backend. The firewall scoping below lives in extraInputRules, which
    # ONLY applies on the nftables firewall — on iptables it silently evaporates.
    # tailscale used to flip nftables on; now that bifrost is off the tailnet that
    # coupling is gone, so set it explicitly or headscale's :8080 accept disappears
    # and the control plane is firewalled to :22 only. No Docker here, so it's safe.
    nftables.enable = true;
    # bifrost lives on its own control VLAN50 (F2/§4 Option A). headscale :8080 is
    # reachable only from portunus (10.0.40.2, still in VLAN40), which terminates TLS
    # for headscale.dysthesis.com and reverse-proxies to 10.0.50.2:8080 across the
    # single heimdall VLAN40->VLAN50 pinhole.
    firewall = {
      # Headplane is a management UI, so do NOT trust tailscale0 wholesale. Open
      # only :443  on the tailnet.
      #
      # Must keep "lo": the firewall module's loopback accept is built from this
      # list, and dropping it makes the resolved stub (127.0.0.53) unreachable,
      # breaking DNS for c-ares clients like nix (glibc/NSS still works via
      # D-Bus).
      trustedInterfaces = lib.mkForce ["lo"];
      # portunus (10.0.40.2) is the only host that proxies to headscale :8080. The
      # :22 scoping (VLAN20-only, excludes the DMZ) now comes from the proxmox
      # profile fleet-wide, so it is not repeated here.
      extraInputRules = ''
        ip saddr 10.0.40.2/32 tcp dport ${toString config.laplace.services.headscale.port} accept
      '';
    };
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.50.2/24";
      Gateway = "10.0.50.1";
      DNS = "10.0.50.1";
      DHCP = "no";
    };
  };

  laplace = {
    harden = ["malloc"];
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 2048; # MiB, ballooning ceiling
      balloon = 384; # MiB, ballooning floor (headscale + headplane are light)
      diskSize = "64G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      headscale = {
        enable = true;
        openFirewall = false;
        fqdn = "${subdomain}.${fqdn}";
        baseDomain = "tailnet.${fqdn}";

        # Headscale runs allow-all until this loads, then flips to default-deny.
        # The whole policy is derived fleet-wide from the SSOT
        # (system/tailnet/headscale.nix): flows -> rules (tag->tag:port), guests
        # -> groups, node tags -> tagOwners, exit -> autoApprovers. This host only
        # flips it on; the hand-written groups/rules/tagOwners that used to live
        # here are gone (the SSOT renderer supersedes them, incl. the tag:phone
        # parity hook and the broad autoApprovers=group:admin, now tag:exit = F5).
        acl.enable = true;

        settings.dns = {
          override_local_dns = true;
          nameservers.global = [adguardTailnetIp];

          # MagicDNS records. each *.dysthesis.com name resolves to the tailnet
          # IP of the node that now fronts that app with its own Caddy. The
          # names are bare *.dysthesis.com that are only resolvable _inside_ the
          # Tailnet, so the tailscale client answers these explicit records and
          # off-tailnet gets NXDOMAIN from public DNS.
          extra_records = [
            {
              name = "immich.${fqdn}";
              type = "A";
              value = mnemeTailnetIp;
            }
            {
              name = "adguard.${fqdn}";
              type = "A";
              value = adguardTailnetIp;
            }
            {
              name = "miniflux.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "silverbullet.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "tasks.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "status.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "cal.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "search.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "wallabag.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "mc.${fqdn}";
              type = "A";
              value = lokiTailnetIp;
            }
          ];
        };
      };
      # SSH/pull: bifrost is off the tailnet (control VLAN50), so the hub dials IN.
      # It listens on :45876, scoped to mimir only; OPNsense must pass VLAN20
      # (mimir 10.0.20.83) -> 10.0.50.2:45876. KEY is the hub's PUBLIC key (same
      # string as portunus / the old WS env files), so no sops.
      beszel.agent = {
        enable = true;
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
        trustedHubs = ["10.0.20.83"];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
    age
  ];
}
