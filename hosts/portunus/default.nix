{
  config,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  ddnsHost = "portunus.${fqdn}";
  headscaleHost = "headscale.${fqdn}";
  headscaleUpstream = "10.0.50.2:8080";
  # Caddy proxies Forgejo across VLAN40 to VLAN70. Its CNAME follows ddclient.
  gitHost = "git.${fqdn}";
  gitUpstream = "10.0.70.2:8080";
  # Loopback TCP avoids Unix socket ownership coupling with DynamicUser.
  gitAnubis = "127.0.0.1:8923";
in {
  sops.secrets = {
    cloudflare_ddns_token.sopsFile = ../../system/secrets/portunus.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/portunus.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/portunus.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.40.1"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
    firewall.allowedTCPPorts = [80 443];
    # Beszel's scoped extraInputRules requires nftables.
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.40.2/24";
      Gateway = "10.0.40.1";
      DNS = "10.0.40.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    harden = ["malloc" "kernel"];
    proxmox = {
      cores = 1;
      memory = 1024; # MiB, ballooning ceiling
      balloon = 1024; # MiB, fixed to avoid swap pressure
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
        role = "edge";
        metrics = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      # Mimir pulls metrics from this DMZ host through a scoped VLAN rule.
      # The agent stores only the hub's public key.
      beszel.agent = {
        enable = true;
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
        trustedHubs = ["10.0.20.83"];
      };
      caddy = {
        enable = true;
        virtualHosts = {
          ${headscaleHost}.extraConfig = ''
            @notSSE not header Accept *text/event-stream*
            encode @notSSE
            reverse_proxy http://${headscaleUpstream}
          '';
          # Anubis returns 500 without a client IP header.
          ${gitHost}.extraConfig = ''
            @notSSE not header Accept *text/event-stream*
            encode @notSSE
            reverse_proxy http://${gitAnubis} {
              header_up X-Real-Ip {client_ip}
              header_up X-Forwarded-For {client_ip}
            }
          '';
        };
      };
    };
  };

  # Browser traffic passes through Anubis; git clients bypass challenges.
  services.anubis.instances.git = {
    settings = {
      BIND = gitAnubis;
      BIND_NETWORK = "tcp";
      TARGET = "http://${gitUpstream}";
      # Preserve private client IPs when Anubis rewrites X-Forwarded-For.
      XFF_STRIP_PRIVATE = false;
    };
    policy.extraBots = [
      {
        name = "git-clients";
        user_agent_regex = "^git/";
        action = "ALLOW";
      }
    ];
  };

  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    server = "api.cloudflare.com/client/v4";
    username = "token";
    passwordFile = config.sops.secrets.cloudflare_ddns_token.path;
    zone = fqdn;
    # headscaleHost is a CNAME; only manage its target here.
    domains = [ddnsHost];
    usev6 = "";
    interval = "5min";
    extraConfig = ''
      ttl=1
    '';
  };

  # Avoid nixpkgs#350408: DynamicUser may be absent from NSS in ExecStartPre.
  users.groups.ddclient = {};
  users.users.ddclient = {
    isSystemUser = true;
    group = "ddclient";
  };
  systemd.services.ddclient.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "ddclient";
    Group = "ddclient";
  };

  mnemosyne.dirs = [
    "/var/lib/acme"
    "/var/lib/caddy"
    "/var/lib/ddclient"
  ];

  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
