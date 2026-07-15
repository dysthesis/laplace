{
  config,
  pkgs,
  ...
}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.10/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 1024; # MiB, ballooning ceiling
      balloon = 256; # MiB, ballooning floor (tailscaled exit node idles ~30-50 MiB)
      diskSize = "20G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;
    services = {
      telemetry = {
        enable = true;
        role = "exit";
        metrics = {
          remoteWriteUrl = "https://telemetry.dysthesis.com:8443/charon/metrics";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          url = "https://telemetry.dysthesis.com:8444/charon/journald";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      tailscale = {
        enable = true;
        # ip_forward + ipv6 forwarding come bundled with this option.
        advertiseExitNode = true;
      };
      beszel.agent = {
        enable = true;
        hubUrl = "https://status.dysthesis.com";
        environmentFile = config.sops.secrets.beszel_agent_env.path;
      };
    };
  };

  sops.secrets = {
    beszel_agent_env.sopsFile = ../../system/secrets/charon.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/charon.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/charon.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };
  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
