{
  config,
  cluster,
  pkgs,
  ...
}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "${cluster.hosts.horos.lan.ip}/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
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
      firewallPolicy.enable = true;
      fail2ban.enable = true;
    };
    zram.enable = true;
    services = {
      tailscale.enable = true;
      telemetry = {
        role = "notifications";
        clientIdentity = {
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
        };
      };
    };
  };

  sops.secrets = {
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/horos.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/horos.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  environment.systemPackages = with pkgs; [git vim];
}
