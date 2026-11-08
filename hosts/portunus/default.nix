{
  config,
  cluster,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  ddnsHost = "portunus.${fqdn}";
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
    firewall.allowedTCPPorts = [80 443];
    # Beszel's extraInputRules must use nftables.
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "${cluster.hosts.portunus.lan.ip}/24";
      Gateway = "10.0.40.1";
      DNS = "10.0.40.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 1024; # MiB
      balloon = 1024; # MiB, fixed memory
      diskSize = "20G";
    };
    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;
    services = {
      telemetry = {
        role = "edge";
        clientIdentity = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
      caddy.enable = true;
    };
  };

  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    server = "api.cloudflare.com/client/v4";
    username = "token";
    passwordFile = config.sops.secrets.cloudflare_ddns_token.path;
    zone = fqdn;
    # Public service CNAMEs use this machine's DDNS identity.
    domains = [ddnsHost];
    usev6 = "";
    interval = "5min";
    extraConfig = ''
      ttl=1
    '';
  };

  # NSS does not always contain the DynamicUser account during ExecStartPre (nixpkgs#350408).
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
