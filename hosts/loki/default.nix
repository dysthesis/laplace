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
    # Use the local cache first. Use the gateway when the cache cannot supply records.
    nameservers = ["127.0.0.1" "10.0.60.1"];
  };

  # Cache and serve stale records when the gateway DNS is not available.
  # Disable DNSSEC validation because the gateway is the trust boundary.
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

  # Keep the modpack host on VLAN60. Transmit only telemetry and deployment traffic between VLANs.
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
      cores = 4; # Minecraft uses a main-tick thread, chunk-generation workers and garbage-collection workers.
      memory = 12288; # MiB, 8 GiB heap plus 4 GiB overhead
      balloon = 0; # A fixed allocation prevents zram and garbage-collection stalls.
      diskSize = "64G"; # Increase space for the world and modpack before a large chunk pregeneration.
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
        # Use only public DNS names to prevent tailnet DNS delays.
        denyDNS = true;
      };

      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        # Policy rules open ports 80 and 443 only on the tailnet.
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/loki.yaml; # This file must contain a cloudflare_api_key key.
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
