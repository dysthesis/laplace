# Forgejo runner guest. VLAN80 limits untrusted CI; jobs use Forgejo on VLAN70.
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
    # SSH scoping requires nftables.
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
      memory = 6144; # MiB, ballooning ceiling (nix evals/builds burst)
      balloon = 6144; # MiB, fixed allocation required by representative Nix CI
      # simplification: 64G is an estimate; enable GC or enlarge it when measured.
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
