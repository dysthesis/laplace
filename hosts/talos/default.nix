# Forgejo runner guest. VLAN80 limits untrusted CI; jobs use Forgejo on VLAN70.
{
  config,
  pkgs,
  ...
}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.80.1"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
    # SSH scoping requires nftables.
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.80.2/24";
      Gateway = "10.0.80.1";
      DNS = "10.0.80.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    harden = ["malloc" "kernel"];
    proxmox = {
      cores = 4;
      memory = 6144; # MiB, ballooning ceiling (nix evals/builds burst)
      balloon = 6144; # MiB, fixed allocation required by representative Nix CI
      # simplification: 64G is an estimate; enable GC or enlarge it when measured.
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
      forgejo-runner = {
        enable = true;
        url = "http://10.0.70.2:8080";
        tokenFile = config.sops.secrets.action_runner.path;
      };
      telemetry = {
        enable = true;
        role = "ci-runner";
        metrics = {
          remoteWriteUrl = "https://telemetry.dysthesis.com:8443/talos/metrics";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          url = "https://telemetry.dysthesis.com:8444/talos/journald";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
    };
  };

  # Registration credentials use this host's SOPS age key.
  sops.secrets = {
    action_runner.sopsFile = ../../system/secrets/talos.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/talos.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/talos.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
