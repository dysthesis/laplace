# Caddy is the only web ingress for this tailnet-only music automation guest.
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
      Address = "${cluster.hosts.apollo.lan.ip}/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4;
      memory = 4096; # MiB. Keep memory available for Lidarr imports and Navidrome transcoding.
      balloon = 2048; # MiB. Keep this minimum for the six idle daemons to prevent swapping.
      diskSize = "256G";
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
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false; # nftables lets only approved tailnet identities use port 443.
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/apollo.yaml;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
