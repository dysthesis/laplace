{
  config,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  subdomain = "headscale";
  # Tailnet IPs of the nodes that now front their own apps with a per-node Caddy
  # (the central horos proxy is retired). Each *.dysthesis.com name resolves to its
  # app's node; the headscale ACL then gates per node:port - which a single shared
  # listener could never do.
  adguardTailnetIp = "100.64.0.5"; # hermes - AdGuard (also the tailnet resolver)
  mnemeTailnetIp = "100.64.0.6"; # mneme - immich
  mimirTailnetIp = "100.64.0.8"; # mimir - miniflux + silverbullet
  bifrostTailnetIp = "100.64.0.11"; # bifrost (this host) - headplane
  lokiTailnetIp = "100.64.0.12"; # loki - minecraft
in {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.40.1"];
    hosts."10.0.40.2" = ["headscale.dysthesis.com"];
    # Headscale is reachable only from VLAN40: portunus terminates TLS for
    # headscale.dysthesis.com and reverse-proxies to 10.0.40.3:8080 over the
    # trusted infra segment.
    firewall = {
      # Headplane is a management UI, so do NOT trust tailscale0 wholesale. Open
      # only :443 (this host's own Caddy fronting headplane.dysthesis.com) on the
      # tailnet; the headscale ACL is the real gate (only group:admin reaches
      # bifrost:443 - guest cohorts have no rule to it), and headplane binds
      # localhost so nothing but this Caddy can reach :3000.
      # Drop tailscale0 from trustedInterfaces (set in system/services/tailscale)
      # so the tailnet isn't trusted wholesale - only :443 via extraInputRules.
      # Must keep "lo": the firewall module's loopback accept is built from this
      # list, and dropping it makes the resolved stub (127.0.0.53) unreachable,
      # breaking DNS for c-ares clients like nix (glibc/NSS still works via D-Bus).
      trustedInterfaces = lib.mkForce ["lo"];
      extraInputRules = ''
        ip saddr 10.0.40.0/24 tcp dport ${toString config.laplace.services.headscale.port} accept
        iifname "${config.services.tailscale.interfaceName}" tcp dport 443 accept
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

        # Declarative tailnet ACL. Headscale runs allow-all until this loads, then
        # flips to default-deny, so the `admin` self-mesh is what keeps the existing
        # fleet talking; guest cohorts are walled off to one backend each. Per-app
        # isolation gates a real node:port - which works because every app now has
        # its own per-node Caddy, not a shared listener an L3/L4 ACL couldn't split.
        # See system/services/headscale/acl.nix.
        acl = {
          enable = true;
          hosts = {
            mc = "${lokiTailnetIp}/32"; # loki's Minecraft server, direct (no horos hop)
            adguard = "${adguardTailnetIp}/32"; # hermes' AdGuard, the tailnet resolver
            immich = "${mnemeTailnetIp}/32"; # mneme's immich Caddy
          };
          groups = {
            # Your fleet: every infra + personal node is user `demiurge`. The
            # self-mesh restores connectivity once the deny-all policy loads.
            admin = {
              members = ["demiurge"];
              # group:admin:* meshes your own nodes; autogroup:internet:* is the
              # separate grant that lets them egress to the wider internet through
              # an exit node (charon). Without it the default-deny policy still lets
              # a node reach charon-the-device, but charon drops the forwarded
              # phone->internet packets because the destination is not an admin node.
              destinations = ["group:admin:*" "autogroup:internet:*"];
            };

            # Minecraft guests: loki's Minecraft port (TCP 25565), Simple Voice Chat
            # (UDP 24454 - voice data; the handshake rides the 25565 plugin channel,
            # so both ports are required), and DNS, nothing else. adguard:53 because
            # override_local_dns routes all of a client's DNS there; without it their
            # device loses general resolution.
            minecraft = {
              members = ["tom" "olivia" "ash" "anika" "mary"];
              destinations = ["mc:25565" "mc:24454" "adguard:53"];
            };

            # Immich guests: immich's own Caddy on mneme:443, plus DNS. Hitting that
            # node's dedicated :443 (not a shared horos:443) is what keeps them off
            # every other web app and the headplane control plane.
            photos = {
              members = ["sheva"];
              destinations = ["immich:443" "adguard:53"];
            };
          };

          # charon advertises 0.0.0.0/0 + ::/0 as an exit node. Auto-approve those
          # routes for any node you own, so a charon re-register doesn't silently
          # drop the routes (and thus egress) until a manual `approve-routes`.
          autoApprovers = {
            exitNode = ["group:admin"];
          };
        };

        settings.dns = {
          override_local_dns = true;
          nameservers.global = [adguardTailnetIp];

          # MagicDNS records: each *.dysthesis.com name resolves to the tailnet IP
          # of the node that now fronts that app with its own Caddy (the central
          # horos proxy is retired). The names are bare *.dysthesis.com with no
          # public Cloudflare A record, so they resolve only here - the tailscale
          # client answers these explicit records and off-tailnet gets NXDOMAIN from
          # public DNS.
          extra_records = [
            {
              name = "headplane.${fqdn}";
              type = "A";
              value = bifrostTailnetIp;
            }
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
              name = "mc.${fqdn}";
              type = "A";
              value = lokiTailnetIp;
            }
          ];
        };
      };

      headplane = {
        enable = true;
        fqdn = "headplane.${fqdn}";
        # Fronted by this host's own Caddy; bind localhost so only Caddy reaches
        # :3000 (the port is never opened and tailscale0 isn't trusted anyway).
        address = "127.0.0.1";
        openFirewall = false;
      };

      tailscale.enable = true;

      # headplane's own TLS frontend (no central horos proxy). :443 is allowed on
      # tailscale0 by the firewall rule above; the headscale ACL restricts it to
      # group:admin (guest cohorts have no rule to bifrost).
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false; # :443 reached over tailscale0 (firewall rule above)
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/cloudflare.yaml;
          proxies."headplane.${fqdn}" = "localhost:3000";
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
    age
  ];
}
