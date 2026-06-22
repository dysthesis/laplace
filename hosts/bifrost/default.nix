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
  mimirTailnetIp = nodes.mimir.ip; # miniflux + silverbullet
  lokiTailnetIp = nodes.loki.ip; # minecraft
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

          # Forced tag for the phones (current `phone` 100.64.0.2, old `device`
          # 100.64.0.7). Assigning a tag at runtime STRIPS a node's user identity
          # for ACL matching: a tagged node stops counting as a group:admin member
          # and is matched only by `tag:phone`. The parity rule below re-grants
          # today's reach so tagging does not cut the device off; tighten its dst
          # later to actually restrict the phones. Apply the runtime
          # `headscale nodes tag` step only AFTER this policy is deployed.
          tagOwners."tag:phone" = ["group:admin"];
          rules = [
            {
              src = ["tag:phone"];
              dst = ["group:admin:*" "autogroup:internet:*"];
            }
          ];

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
              members = ["tom" "olivia" "ash" "anika" "mary" "esther"];
              destinations = [
                "mc:25565" # The server itself
                "mc:24454" # Simple Voice Chat (via UDP)
                "adguard:53" # AdGuard because it's the Tailnet's default DNS
                # NB: no autogroup:internet — that grant is exit-node egress, not
                # "reach the game". It let guests tunnel out the home IP (F4).
              ];
            };

            photos = {
              members = ["sheva"];
              destinations = [
                "immich:443" # Immich itself (behind Caddy)
                "adguard:53" #  AdGuard because it's the Tailnet's default DNS
                # NB: no autogroup:internet — exit-node egress, not "reach photos" (F4).
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

      # headplane = {
      #   enable = true;
      #   fqdn = "headplane.${fqdn}";
      #   address = "127.0.0.1";
      #   openFirewall = false;
      # };

      # tailscale.enable = true;

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
