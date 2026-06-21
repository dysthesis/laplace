{
  config,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  subdomain = "headscale";
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
    # nftables backend. The firewall scoping below lives in extraInputRules, which
    # ONLY applies on the nftables firewall — on iptables it silently evaporates.
    # tailscale used to flip nftables on; now that bifrost is off the tailnet that
    # coupling is gone, so set it explicitly or headscale's :8080 accept disappears
    # and the control plane is firewalled to :22 only. No Docker here, so it's safe.
    nftables.enable = true;
    # Headscale is reachable only from VLAN40: portunus terminates TLS for
    # headscale.dysthesis.com and reverse-proxies to 10.0.40.3:8080 over the
    # trusted infra segment.
    firewall = {
      # Headplane is a management UI, so do NOT trust tailscale0 wholesale. Open
      # only :443  on the tailnet.
      #
      # Must keep "lo": the firewall module's loopback accept is built from this
      # list, and dropping it makes the resolved stub (127.0.0.53) unreachable,
      # breaking DNS for c-ares clients like nix (glibc/NSS still works via
      # D-Bus).
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

        #  Headscale runs allow-all until this loads, then flips to default-deny,
        # so the `admin` self-mesh is what keeps the existing fleet talking;
        # guest cohorts are walled off to one backend each.
        acl = {
          enable = true;
          hosts = {
            mc = "${lokiTailnetIp}/32";
            adguard = "${adguardTailnetIp}/32";
            immich = "${mnemeTailnetIp}/32";
          };
          groups = {
            admin = {
              members = ["demiurge"];
              # group:admin:* meshes our own nodes; autogroup:internet:* is the
              # separate grant that lets them egress to the wider internet through
              # an exit node (charon). Without it the default-deny policy still
              # lets a node reach charon-the-device, but charon drops the
              # forwarded phone-to-internet packets because the destination is
              # not an admin node.
              destinations = ["group:admin:*" "autogroup:internet:*"];
            };

            minecraft = {
              members = ["tom" "olivia" "ash" "anika" "mary"];
              destinations = [
                "mc:25565" # The server itself
                "mc:24454" # Simple Voice Chat (via UDP)
                "adguard:53" # AdGuard because it's the Tailnet's default DNS
              ];
            };

            photos = {
              members = ["sheva"];
              destinations = [
                "immich:443" # Immich itself (behind Caddy)
                "adguard:53" #  AdGuard because it's the Tailnet's default DNS
              ];
            };
          };

          # charon advertises 0.0.0.0/0 + ::/0 as an exit node. Auto-approve
          # those routes for any node we own, so a charon re-register doesn't
          # silently drop the routes (and thus egress) until a manual
          # `approve-routes`.
          autoApprovers = {
            exitNode = ["group:admin"];
          };
        };

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
              name = "status.${fqdn}";
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
        address = "127.0.0.1";
        openFirewall = false;
      };

      tailscale.enable = true;

      # SSH/pull: bifrost is in the DMZ and off the tailnet, so the hub dials IN.
      # It listens on :45876, scoped to mimir only; OPNsense must also pass VLAN20
      # (mimir 10.0.20.83) -> 10.0.40.3:45876. KEY is the hub's PUBLIC key (same
      # string as portunus / the old WS env files), so no sops.
      beszel.agent = {
        enable = true;
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
        trustedHubs = ["10.0.20.83"];
      };

      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false;
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
