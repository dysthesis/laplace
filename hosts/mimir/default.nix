# Application guest. Caddy fronts loopback services on tailnet-only port 443.
{
  config,
  cluster,
  pkgs,
  ...
}: {
  sops.secrets = {
    # Beszel KEY and TOKEN environment file.
    beszel_agent_env.sopsFile = ../../system/secrets/mimir.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/mimir.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/mimir.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "${cluster.hosts.mimir.lan.ip}/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 2;
      memory = 5120; # MiB, ballooning ceiling (karakeep's node stack + headless chromium)
      balloon = 1280; # MiB, ballooning floor (Postgres + app processes)
      diskSize = "32G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      tailscale.enable = true;
      telemetry = {
        role = "apps";
        metrics = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      beszel = {
        agent = {
          environmentFile = config.sops.secrets.beszel_agent_env.path;
        };
      };

      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false; # tailnet-only; :443 reached over tailscale0
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/mimir.yaml;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
