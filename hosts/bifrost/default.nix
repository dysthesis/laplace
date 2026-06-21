{
  config,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  subdomain = "headscale";
  horosTailnetIp = "100.64.0.10";
  # hermes' tailnet IP, where AdGuard binds 0.0.0.0:53. Shared by the resolver
  # push (override_local_dns) and the ACL host alias friends use for DNS.
  adguardTailnetIp = "100.64.0.5";
  # mneme's tailnet IP. Immich binds 0.0.0.0:2283 there and is ACL-gated per-cohort
  # at that real backend, NOT behind horos:443 (where one Caddy listener muxes every
  # web app + the headplane UI into a single object an L3/L4 ACL cannot split). So
  # immich.dysthesis.com resolves straight here, bypassing the proxy.
  mnemeTailnetIp = "100.64.0.6";
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
        fqdn = "${subdomain}.${fqdn}";
        baseDomain = "tailnet.${fqdn}";

        # Declarative tailnet ACL. Headscale runs allow-all until this loads, then
        # flips to default-deny, so the `admin` self-mesh is what keeps the existing
        # fleet talking; guest cohorts are walled off to one backend each. Per-app
        # isolation gates the real backend node:port, never horos:443 (one Caddy
        # listener fronts every web app + headplane, indistinguishable to an L3/L4
        # ACL); minecraft is the exception - a dedicated port on horos.
        # See system/services/headscale/acl.nix.
        acl = {
          enable = true;
          hosts = {
            mc = "${horosTailnetIp}/32"; # horos socket-proxies :25565 onward to loki
            adguard = "${adguardTailnetIp}/32"; # hermes' AdGuard, the tailnet resolver
            immich = "${mnemeTailnetIp}/32"; # immich's real backend; bypasses the horos:443 mux
          };
          groups = {
            # Your fleet: every infra + personal node is user `demiurge`. The
            # self-mesh restores connectivity once the deny-all policy loads.
            admin = {
              members = ["demiurge"];
              destinations = ["group:admin:*"];
            };

            # Minecraft guests: the loki ingress (a dedicated port on horos) and DNS,
            # nothing else. adguard:53 because override_local_dns routes all of a
            # client's DNS there; without it their device loses general resolution.
            minecraft = {
              members = ["tom" "olivia" "ash" "anika" "mary"];
              destinations = ["mc:25565" "adguard:53"];
            };

            # Immich guests: immich's mneme backend directly, plus DNS. Hitting the
            # real node:port (not horos:443) is what keeps them off every other web
            # app and the headplane control plane.
            photos = {
              members = ["sheva"];
              destinations = ["immich:2283" "adguard:53"];
            };
          };
        };

        settings.dns = {
          override_local_dns = true;
          nameservers.global = [adguardTailnetIp];

          # MagicDNS records for the apps behind the central Caddy on horos. Most
          # service names point at horos's *tailnet* IP (100.x), not its LAN
          # address, so the traffic rides WireGuard and horos proxies each to the
          # app's own node over the tailnet. Immich is the exception (see below): it
          # resolves straight to its backend so the ACL can gate it per-cohort. The
          # names are bare *.dysthesis.com
          # with no public Cloudflare A record, so they resolve only here - the
          # tailscale client answers these explicit records and off-tailnet gets
          # NXDOMAIN from public DNS.
          extra_records = let
            horos = horosTailnetIp;
            mneme = mnemeTailnetIp;
          in [
            {
              name = "headplane.${fqdn}";
              type = "A";
              value = horos;
            }
            # Resolves to mneme, not horos: immich is ACL-gated per-cohort at
            # mneme:2283, so it is deliberately off the shared horos Caddy. Served
            # over the tailnet (WireGuard-encrypted); add a cert on mneme for browser
            # TLS / the immich PWA if you want it.
            {
              name = "immich.${fqdn}";
              type = "A";
              value = mneme;
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
              name = "mc.${fqdn}";
              type = "A";
              value = horos;
            }
          ];
        };
      };

      headplane = {
        enable = true;
        fqdn = "headplane.${fqdn}";
        # Horos proxies this over the tailnet. The port is not opened globally;
        # host firewall allows only horos's tailnet IP to connect.
        address = "0.0.0.0";
        openFirewall = false;
      };

      tailscale.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
