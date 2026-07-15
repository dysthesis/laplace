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
      balloon = 384; # MiB, ballooning floor (AdGuard idles ~150 MiB; headroom for filter lists/query log)
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
          remoteWriteUrl = "https://telemetry.dysthesis.com:8443/hermes/metrics";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          url = "https://telemetry.dysthesis.com:8444/hermes/journald";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      # WS/push: hermes is on the tailnet, so the agent dials OUT to the hub. The
      # hub binds loopback on mimir behind a tailnet-only Caddy, so the only way in
      # is https://status.dysthesis.com over tailscale0 — not mimir's :8090
      # (loopback) nor its LAN :443 (tailscale0-only).
      beszel.agent = {
        enable = true;
        hubUrl = "https://status.dysthesis.com";
        environmentFile = config.sops.secrets.beszel_agent_env.path;
      };
      tailscale = {
        enable = true;
        # AdGuard owns 0.0.0.0:53 here; keep tailscaled from pulling in
        # systemd-resolved and squatting tcp/53 via its loopback stubs.
        denyDNS = true;
      };

      # AdGuard's own TLS frontend (no central proxy). adguard.dysthesis.com
      # resolves to hermes now and is reached over the tailnet (admin-only via ACL).
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

  # AdGuard owns 0.0.0.0:80 (its web UI); stop Caddy from also grabbing :80 for
  # HTTP->HTTPS redirects. DNS-01 needs no :80, so Caddy listens on :443 only.
  services.caddy.globalConfig = "auto_https disable_redirects";
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
    # tailscale runs with denyDNS here (AdGuard owns :53), so MagicDNS can't
    # resolve the tailnet-only hub name and the system resolver (10.0.20.1) returns
    # NXDOMAIN. Pin it to mimir's tailnet IP; the agent reaches the hub's Caddy over
    # tailscale0 and the cert SNI still matches.
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
