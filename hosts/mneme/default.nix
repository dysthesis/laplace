{
  config,
  pkgs,
  ...
}: {
  sops.secrets = {
    beszel_agent_env.sopsFile = ../../system/secrets/mneme.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/mneme.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/mneme.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4;
      memory = 8096; # MiB, ballooning ceiling
      balloon = 2048; # MiB, ballooning floor
      diskSize = "256G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      immich.enable = true;
      tailscale.enable = true;
      telemetry = {
        enable = true;
        role = "photos";
        metrics = {
          remoteWriteUrl = "https://telemetry.dysthesis.com:8443/mneme/metrics";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          url = "https://telemetry.dysthesis.com:8444/mneme/journald";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      beszel.agent = {
        enable = true;
        hubUrl = "https://status.dysthesis.com";
        environmentFile = config.sops.secrets.beszel_agent_env.path;
      };

      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/mneme.yaml;
          proxies."immich.dysthesis.com" = "localhost:2283";
        };
      };
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.81/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
