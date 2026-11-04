{
  cluster,
  pkgs,
  ...
}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "${cluster.hosts.argus.lan.ip}/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  # PVE attaches one 128 GiB virtio disk with backup=0.
  # See docs/observability.md for the partition labels.
  fileSystems = {
    "/var/lib/private/victoriametrics" = {
      device = "/dev/disk/by-label/argus-metrics";
      fsType = "ext4";
      options = ["nofail" "noatime" "x-systemd.device-timeout=10s"];
    };
    "/var/lib/private/victorialogs" = {
      device = "/dev/disk/by-label/argus-logs";
      fsType = "ext4";
      options = ["nofail" "noatime" "x-systemd.device-timeout=10s"];
    };
  };

  laplace = {
    profiles = ["proxmox"];
    harden = ["malloc" "kernel"];
    proxmox = {
      cores = 4;
      memory = 6144;
      balloon = 4096;
      diskSize = "32G";
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
        role = "observability";
      };
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/argus.yaml;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [git vim];
}
