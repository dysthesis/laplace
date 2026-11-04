# Keep untrusted CI jobs on VLAN80, separate from Forgejo on VLAN70.
{
  config,
  cluster,
  pkgs,
  ...
}: {
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  programs.ccache.enable = true;

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.80.1"];
    # Use nftables for SSH access limits.
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "${cluster.hosts.talos.lan.ip}/24";
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
      memory = 6144; # MiB, for Nix evaluation and builds
      balloon = 6144; # MiB. Fixed memory is necessary for Nix CI.
      # This capacity is an estimate. Measure disk use before you increase it or enable garbage collection.
      diskSize = "64G";
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
        role = "ci-runner";
        clientIdentity = {
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
    };
  };

  sops.secrets = {
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
