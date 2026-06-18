{
  config,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  ddnsHost = "portunus.${fqdn}";
in {
  sops.secrets = {
    cloudflare_acme_env = {};
    cloudflare_ddns_token = {};
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.40.1"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.40.2/24";
      Gateway = "10.0.40.1";
      DNS = "10.0.40.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 2048; # MiB
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

    nh = {
      enable = true;
      flakePath = "/etc/config";
    };

    services.caddy = {
      enable = true;
      acme.cloudflareDns01 = {
        enable = true;
        environmentFile = config.sops.secrets.cloudflare_acme_env.path;
      };
    };
  };

  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    server = "api.cloudflare.com/client/v4";
    username = "token";
    passwordFile = config.sops.secrets.cloudflare_ddns_token.path;
    zone = fqdn;
    domains = [ddnsHost];
    usev6 = "";
    interval = "5min";
    extraConfig = ''
      ttl=1
    '';
  };

  mnemosyne.dirs = [
    "/etc/config"
    "/var/lib/acme"
    "/var/lib/caddy"
    "/var/lib/ddclient"
  ];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
