# Forgejo guest. VLAN70 port 8080 accepts only portunus and talos.
{
  config,
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
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
    # extraInputRules and SSH scoping require nftables.
    nftables.enable = true;
    # Allow only the portunus proxy and talos runner; OPNsense routes both VLANs.
    firewall.extraInputRules = ''
      ip saddr { 10.0.40.2, 10.0.80.2 } tcp dport ${toString config.services.forgejo.settings.server.HTTP_PORT} accept
    '';
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.70.2/24";
      Gateway = "10.0.70.1";
      DNS = "10.0.70.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    harden = ["malloc"];
    proxmox = {
      cores = 4;
      memory = 6144; # MiB, ballooning ceiling
      balloon = 2048; # MiB, floor avoids swap pressure
      diskSize = "128G";
      # Proxmox assigns zero MACs during restore.
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
      forgejo.enable = true;
      telemetry = {
        enable = true;
        role = "git";
        metrics = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
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
