{
  config,
  pkgs,
  ...
}: let
  uptimeHost = "uptime.dysthesis.com";
  ntfyHost = "ntfy.dysthesis.com";
in {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.85/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    harden = ["malloc" "kernel"];
    proxmox = {
      cores = 1;
      memory = 2048;
      balloon = 1280;
      diskSize = "16G";
    };
    security = {
      privesc = "doas";
      apparmor.enable = true;
      polkit.enable = true;
      firewall.enable = true;
      fail2ban.enable = true;
    };
    zram.enable = true;
    services = {
      tailscale.enable = true;
      telemetry = {
        enable = true;
        role = "notifications";
        metrics = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/horos.yaml;
          proxies = {
            ${uptimeHost} = "localhost:3001";
            ${ntfyHost} = "localhost:2586";
          };
        };
      };
    };
  };

  services = {
    uptime-kuma = {
      enable = true;
      settings = {
        HOST = "127.0.0.1";
        PORT = "3001";
      };
    };
    ntfy-sh = {
      enable = true;
      environmentFile = config.sops.secrets.ntfy_env.path;
      settings = {
        base-url = "https://${ntfyHost}";
        listen-http = "127.0.0.1:2586";
        behind-proxy = true;
        auth-default-access = "deny-all";
        enable-login = true;
        enable-signup = false;
        require-login = true;
        keepalive-interval = "45s";
        upstream-base-url = "https://ntfy.sh";
      };
    };
  };

  sops.secrets = {
    ntfy_env = {
      sopsFile = ../../system/secrets/horos.yaml;
      restartUnits = ["ntfy-sh.service"];
    };
    # Stored for operator retrieval; ntfy receives only its bcrypt hash.
    ntfy_admin_password.sopsFile = ../../system/secrets/horos.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/horos.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/horos.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  mnemosyne.dirs = [
    "/var/lib/private/uptime-kuma"
    "/var/lib/private/ntfy-sh"
  ];

  environment.systemPackages = with pkgs; [git vim];
}
