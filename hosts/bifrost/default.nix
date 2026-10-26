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
    # extraInputRules only works with nftables.
    nftables.enable = true;
    # Only portunus may reach Headscale across VLAN40 to VLAN50.
    firewall = {
      # Keep the control-plane segment closed except recipe-owned ingress.
      # Keep loopback trusted or c-ares cannot reach resolved on 127.0.0.53.
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
    harden = ["malloc"];
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 2048; # MiB, ballooning ceiling
      balloon = 384; # MiB, ballooning floor (headscale + headplane are light)
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
    age
  ];
}
