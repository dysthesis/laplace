{
  config,
  cluster,
  pkgs,
  ...
}: {
  sops.secrets = {
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/loki.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/loki.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    # Prefer local caching; keep the gateway as fallback.
    nameservers = ["127.0.0.1" "10.0.60.1"];
  };

  # Cache and serve stale records when the gateway DNS fails.
  # The gateway remains the trust boundary, so DNSSEC validation stays off.
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = ["127.0.0.1"];
        access-control = ["127.0.0.0/8 allow"];
        serve-expired = true;
        serve-expired-ttl = 86400;
        prefetch = true;
        cache-min-ttl = 60;
        module-config = ''"iterator"'';
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = ["10.0.60.1"];
        }
      ];
    };
  };

  # Isolate the modpack host on VLAN60; only telemetry and deploy pinholes cross VLANs.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "${cluster.hosts.loki.lan.ip}/24";
      Gateway = "10.0.60.1";
      DNS = "10.0.60.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4; # MC main-tick thread + chunk-gen/GC workers
      memory = 12288; # MiB, 8 GiB heap plus 4 GiB overhead
      balloon = 0; # fixed allocation avoids zram and GC stalls
      diskSize = "64G"; # world + modpack; bump before a large chunk pregen
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      telemetry = {
        role = "game";
        clientIdentity = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      tailscale = {
        enable = true;
        # Avoid cold tailnet DNS links; this host only needs public names.
        denyDNS = true;
      };

      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com"; # ACME account, matches the rest of the fleet
        # Policy rules expose ports 80 and 443 only on the tailnet.
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/loki.yaml; # must hold a `cloudflare_api_key` key
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    rsync
  ];
}
