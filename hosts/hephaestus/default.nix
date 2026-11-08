{
  config,
  cluster,
  pkgs,
  ...
}: {
  sops.secrets = {
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/hephaestus.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/hephaestus.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["127.0.0.1" "10.0.70.1"];
    # Use nftables for extraInputRules and SSH access limits.
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "${cluster.hosts.hephaestus.lan.ip}/24";
      Gateway = "10.0.70.1";
      DNS = "10.0.70.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4;
      memory = 6144; # MiB
      balloon = 2048; # MiB, minimum
      diskSize = "128G";
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
      telemetry = {
        role = "git";
        clientIdentity = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    python3
  ];
}
