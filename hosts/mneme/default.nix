{
  config,
  pkgs,
  ...
}: {
  sops.secrets.beszel_agent_env.sopsFile = ../../system/secrets/mneme.yaml;
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4;
      memory = 8096; # MiB, ballooning ceiling
      balloon = 2048; # MiB, ballooning floor
      diskSize = "256G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      immich.enable = true;
      tailscale.enable = true;
      beszel.agent = {
        enable = true;
        hubUrl = "https://status.dysthesis.com";
        environmentFile = config.sops.secrets.beszel_agent_env.path;
      };

      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false;
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/cloudflare.yaml;
          proxies."immich.dysthesis.com" = "localhost:2283";
        };
      };
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.81/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
