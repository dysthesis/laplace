{
  config,
  pkgs,
  ...
}: {
  sops.secrets = {
    beszel_agent_env.sopsFile = ../../system/secrets/hermes.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/hermes.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/hermes.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 2048; # MiB, ballooning ceiling
      balloon = 384; # MiB, AdGuard plus filter and log headroom
      diskSize = "64G";
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
      adguardhome.enable = true;
      telemetry = {
        enable = true;
        role = "dns";
        metrics = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      # Push metrics to the tailnet-only hub through its Caddy endpoint.
      beszel.agent = {
        enable = true;
        hubUrl = "https://status.dysthesis.com";
        environmentFile = config.sops.secrets.beszel_agent_env.path;
      };
      tailscale = {
        enable = true;
        # AdGuard owns port 53; do not start resolved.
        denyDNS = true;
      };

      # Serve AdGuard TLS directly on the admin-only tailnet route.
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false; # tailnet-only; :443 reached over tailscale0
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/hermes.yaml;
          proxies."adguard.dysthesis.com" = "localhost:80";
        };
      };
    };
  };

  # AdGuard owns port 80; DNS-01 lets Caddy use only port 443.
  services.caddy.globalConfig = "auto_https disable_redirects";
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
    # denyDNS disables MagicDNS, so pin the hub name to mimir's tailnet IP.
    hosts."100.64.0.8" = ["status.dysthesis.com"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
  };
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.82/24";
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
