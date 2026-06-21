# Formerly the central tailnet reverse proxy. Every app it fronted now runs its
# own per-node Caddy (mneme/mimir/hermes/bifrost) and the Minecraft ingress went
# direct to loki, so this host is idle - kept only so a single `just deploy`
# reconfigures it cleanly. Final removal (drop from hosts/default.nix +
# nix/deploy, delete this dir) is the last step once the fold is verified.
{pkgs, ...}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  # VLAN 20.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.85/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 1024; # MiB, ballooning ceiling
      balloon = 384; # MiB, ballooning floor
      diskSize = "15G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      tailscale.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
