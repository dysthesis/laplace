{
  config,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  ddnsHost = "portunus.${fqdn}";
  headscaleHost = "headscale.${fqdn}";
  headscaleUpstream = "10.0.40.3:8080";
in {
  sops.secrets = {
    cloudflare_ddns_token.sopsFile = ../../system/secrets/portunus.yaml;
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
      memory = 1024; # MiB
      diskSize = "20G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    nh = {
      enable = true;
      flakePath = "/etc/config";
    };

    services.caddy = {
      enable = true;
      virtualHosts.${headscaleHost}.extraConfig = ''
        reverse_proxy http://${headscaleUpstream}
      '';
    };
  };

  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    server = "api.cloudflare.com/client/v4";
    username = "token";
    passwordFile = config.sops.secrets.cloudflare_ddns_token.path;
    zone = fqdn;
    # headscaleHost is a CNAME to ddnsHost in Cloudflare, so it follows this
    # A record automatically; managing it here would clash with the CNAME.
    domains = [ddnsHost];
    usev6 = "";
    interval = "5min";
    extraConfig = ''
      ttl=1
    '';
  };

  # Work around nixpkgs#350408: DynamicUser sometimes is not visible to NSS
  # when ddclient's ExecStartPre resolves $USER for install --owner.
  users.groups.ddclient = {};
  users.users.ddclient = {
    isSystemUser = true;
    group = "ddclient";
  };
  systemd.services.ddclient.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "ddclient";
    Group = "ddclient";
  };

  mnemosyne.dirs = [
    "/etc/config"
    "/var/lib/acme"
    "/var/lib/caddy"
    "/var/lib/private/ddclient"
  ];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
