{
  config,
  cluster,
  lib,
  pkgs,
  ...
}: {
  sops.secrets = {
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/bifrost.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/bifrost.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.50.1"];
    # extraInputRules uses nftables.
    nftables.enable = true;
    firewall = {
      # Service rules control network ingress.
      # c-ares must connect to resolved at 127.0.0.53 through loopback.
      trustedInterfaces = lib.mkForce ["lo"];
    };
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "${cluster.hosts.bifrost.lan.ip}/24";
      Gateway = "10.0.50.1";
      DNS = "10.0.50.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 2048; # MiB
      balloon = 384; # MiB, minimum
      diskSize = "64G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      telemetry = {
        role = "control-plane";
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
    age
  ];
}
