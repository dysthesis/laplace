{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  subdomain = "headscale";
  # Fleet tailnet addresses.
  inherit (config.laplace.tailnet) nodes;
  adguardTailnetIp = nodes.hermes.ip; # AdGuard (also the tailnet resolver)
  mnemeTailnetIp = nodes.mneme.ip; # immich
  mimirTailnetIp = nodes.mimir.ip; # miniflux + silverbullet + radicale
  argusTailnetIp = nodes.argus.ip; # Grafana
  horosTailnetIp = nodes.horos.ip; # Uptime Kuma + ntfy
  lokiTailnetIp = nodes.loki.ip; # minecraft

  mullvadConnections = {
    deimos = {
      registeredNodeKey = "nodekey:ddec812440a7cc7728567fe2f8d6d97f5b8411fba6593fe4cdb5035c09a6aa53";
      ipv4MasqAddr = "10.131.163.163";
      ipv6MasqAddr = "fc00:bbbb:bbbb:bb01:d:0:3:a3a3";
    };
    phobos = {
      registeredNodeKey = "nodekey:b3e3b7c895bd9ff16ab73d004ae85a42c7e3aa59b71145881493196119a40324";
      ipv4MasqAddr = "10.143.70.112";
      ipv6MasqAddr = "fc00:bbbb:bbbb:bb01:d:0:f:4670";
    };
    phone = {
      registeredNodeKey = "nodekey:312ee1628d1b5ce0c9a821373e2e8da5a644dcb1efde20be87256325926f5258";
      ipv4MasqAddr = "10.138.113.245";
      ipv6MasqAddr = "fc00:bbbb:bbbb:bb01:d:0:a:71f5";
    };
  };

  mullvadPeer = {
    publicKey ? null,
    publicKeyFile ? null,
    endpoint,
    country,
    countryCode,
    city,
    cityCode,
    latitude,
    longitude,
    priority ? 100,
  }:
    {
      userId = 2; # demiurge
      endpoints = [endpoint];
      allowedIPs = ["0.0.0.0/0" "::/0"];
      exitNodeDNSResolvers = ["10.64.0.1"];
      suggestExitNode = true;
      tags = ["tag:mullvad" "tag:exit-node"];
      location = {
        inherit country countryCode city cityCode latitude longitude priority;
      };
      connections = mullvadConnections;
    }
    // lib.optionalAttrs (publicKey != null) {inherit publicKey;}
    // lib.optionalAttrs (publicKeyFile != null) {inherit publicKeyFile;};
in {
  sops.secrets = {
    mullvad_wg_key.sopsFile = ../../system/secrets/bifrost.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/bifrost.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/bifrost.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  services.headscale.package = inputs.headscale.packages.${pkgs.stdenv.hostPlatform.system}.default;

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.50.1"];
    hosts."10.0.40.2" = ["headscale.dysthesis.com"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
    # extraInputRules only works with nftables.
    nftables.enable = true;
    # Only portunus may reach Headscale across VLAN40 to VLAN50.
    firewall = {
      # Expose the Headplane UI only on tailnet port 443.
      # Keep loopback trusted or c-ares cannot reach resolved on 127.0.0.53.
      trustedInterfaces = lib.mkForce ["lo"];
      # Only portunus proxies Headscale on port 8080.
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

        # Load the fleet-rendered policy before Headscale accepts traffic.
        acl.enable = true;

        wgOnly = {
          enable = true;
          peers = {
            mullvad-au-syd = mullvadPeer {
              publicKeyFile = config.sops.secrets.mullvad_wg_key.path;
              endpoint = "146.70.200.2:51820";
              country = "Australia";
              countryCode = "AU";
              city = "Sydney";
              cityCode = "syd";
              latitude = -33.8688;
              longitude = 151.2093;
            };
            mullvad-au-mel = mullvadPeer {
              publicKey = "ju0S2nDmiOrSm1H68SRTB4mtt2U8SKROprE83VCoF1Y=";
              endpoint = "163.47.16.146:51820";
              country = "Australia";
              countryCode = "AU";
              city = "Melbourne";
              cityCode = "mel";
              latitude = -37.815018;
              longitude = 144.946014;
            };
            mullvad-se-mma = mullvadPeer {
              publicKey = "cwglRdgLQ4gMG36TIYlc5OIemLNrYs4UM1KTc8mnzxk=";
              endpoint = "45.83.220.69:51820";
              country = "Sweden";
              countryCode = "SE";
              city = "Malmö";
              cityCode = "mma";
              latitude = 55.607075;
              longitude = 13.002716;
            };
            mullvad-se-sto = mullvadPeer {
              publicKey = "V5RUvv8xp3xYc9b/KoGjTL6EUEb2mTv+8egxuEvUAnc=";
              endpoint = "89.37.63.10:51820";
              country = "Sweden";
              countryCode = "SE";
              city = "Stockholm";
              cityCode = "sto";
              latitude = 59.3289;
              longitude = 18.0649;
            };
            mullvad-no-osl = mullvadPeer {
              publicKey = "QXR6DwdWn2urvyVNt5pFulLuhkyeuTp2STwGgEQ6Ehw=";
              endpoint = "141.98.253.5:51820";
              country = "Norway";
              countryCode = "NO";
              city = "Oslo";
              cityCode = "osl";
              latitude = 59.916667;
              longitude = 10.75;
            };
            mullvad-no-svg = mullvadPeer {
              publicKey = "kduYoE/b1mA2Pjszx1CzE4Lktsdc2zsUU8Relul2m2U=";
              endpoint = "194.127.199.2:51820";
              country = "Norway";
              countryCode = "NO";
              city = "Stavanger";
              cityCode = "svg";
              latitude = 58.964432;
              longitude = 5.72625;
            };
            mullvad-us-nyc = mullvadPeer {
              publicKey = "OKyEPafS1lnUTWqtVeWElkTzcmkvLi9dncBHbSyFrH8=";
              endpoint = "146.70.185.2:51820";
              country = "USA";
              countryCode = "US";
              city = "New York, NY";
              cityCode = "nyc";
              latitude = 40.73061;
              longitude = -73.935242;
            };
            mullvad-us-was = mullvadPeer {
              publicKey = "2AvJGG4MJfnJMRSR6kcha9FZMMkhJM/AtktI5DSESSI=";
              endpoint = "185.213.193.127:51820";
              country = "USA";
              countryCode = "US";
              city = "Washington DC";
              cityCode = "was";
              latitude = 38.889484;
              longitude = -77.035278;
            };
            mullvad-sg-sin = mullvadPeer {
              publicKey = "sFHv/qzG7b6ds5pow+oAR3G5Wqp9eFbBD3BmEGBuUWU=";
              endpoint = "138.199.60.2:51820";
              country = "Singapore";
              countryCode = "SG";
              city = "Singapore";
              cityCode = "sin";
              latitude = 1.293056;
              longitude = 103.855833;
            };
            mullvad-id-jpu = mullvadPeer {
              publicKey = "XYQvOrRqu8j521Hy/8+jGRDLZoSAssOvCectyKz350Y=";
              endpoint = "129.227.46.130:51820";
              country = "Indonesia";
              countryCode = "ID";
              city = "Jakarta";
              cityCode = "jpu";
              latitude = -6.17511;
              longitude = 106.865036;
            };
            mullvad-dk-cph = mullvadPeer {
              publicKey = "egl+0TkpFU39F5O6r6+hIBMPQLOa8/t5CymOZV6CC3Y=";
              endpoint = "45.129.56.67:51820";
              country = "Denmark";
              countryCode = "DK";
              city = "Copenhagen";
              cityCode = "cph";
              latitude = 55.666667;
              longitude = 12.583333;
            };
            mullvad-fi-hel = mullvadPeer {
              publicKey = "veLqpZazR9j/Ol2G8TfrO32yEhc1i543MCN8rpy1FBA=";
              endpoint = "185.204.1.203:51820";
              country = "Finland";
              countryCode = "FI";
              city = "Helsinki";
              cityCode = "hel";
              latitude = 60.192059;
              longitude = 24.945831;
            };
            mullvad-jp-osa = mullvadPeer {
              publicKey = "uhbuY1A7g0yNu0lRhLTi020kYeAx34ED30BA5DQRHFo=";
              endpoint = "194.114.136.3:51820";
              country = "Japan";
              countryCode = "JP";
              city = "Osaka";
              cityCode = "osa";
              latitude = 34.672314;
              longitude = 135.484802;
            };
            mullvad-ch-zrh = mullvadPeer {
              publicKey = "/iivwlyqWqxQ0BVWmJRhcXIFdJeo0WbHQ/hZwuXaN3g=";
              endpoint = "193.32.127.66:51820";
              country = "Switzerland";
              countryCode = "CH";
              city = "Zurich";
              cityCode = "zrh";
              latitude = 47.366667;
              longitude = 8.55;
            };
          };
        };

        settings.dns = {
          override_local_dns = true;
          nameservers.global = [adguardTailnetIp];

          # Resolve internal app names to their tailnet frontends.
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
              name = "observe.${fqdn}";
              type = "A";
              value = argusTailnetIp;
            }
            {
              name = "uptime.${fqdn}";
              type = "A";
              value = horosTailnetIp;
            }
            {
              name = "ntfy.${fqdn}";
              type = "A";
              value = horosTailnetIp;
            }
            {
              name = "cal.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "read.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "slides.${fqdn}";
              type = "A";
              value = mimirTailnetIp;
            }
            {
              name = "mc.${fqdn}";
              type = "A";
              value = lokiTailnetIp;
            }
            {
              name = "map.${fqdn}";
              type = "A";
              value = lokiTailnetIp;
            } # squaremap web map, same loki Caddy as mc.
          ];
        };
      };
      telemetry = {
        enable = true;
        role = "control-plane";
        metrics = {
          remoteWriteUrl = "https://telemetry.dysthesis.com:8443/bifrost/metrics";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          url = "https://telemetry.dysthesis.com:8444/bifrost/journald";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      # Mimir pulls metrics through a scoped VLAN rule; the agent stores its public key.
      beszel.agent = {
        enable = true;
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
        trustedHubs = ["10.0.20.83"];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    age
  ];
}
