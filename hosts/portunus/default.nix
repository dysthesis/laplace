{
  config,
  lib,
  pkgs,
  ...
}: let
  fqdn = "dysthesis.com";
  ddnsHost = "portunus.${fqdn}";
  headscaleHost = "headscale.${fqdn}";
  headscaleUpstream = "10.0.50.2:8080";
in {
  sops.secrets.cloudflare_ddns_token.sopsFile = ../../system/secrets/portunus.yaml;
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.40.1"];
    firewall.allowedTCPPorts = [80 443];
    # nftables backend so the beszel agent's scoped :45876 rule (extraInputRules)
    # actually applies — it is a silent no-op on the iptables backend. portunus
    # has no tailscale (which would flip this on), and no Docker, so set it here.
    nftables.enable = true;
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
    harden = ["malloc" "kernel"];
    proxmox = {
      cores = 1;
      memory = 1024; # MiB, ballooning ceiling
      balloon = 384; # MiB, ballooning floor (caddy + ddclient are tiny; 384 leaves Go-runtime margin)
      diskSize = "20G";
    };
    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;
    services = {
      # SSH/pull: portunus is in the DMZ and cannot reach the tailnet hub, so the
      # hub dials IN instead. portunus listens on :45876, scoped to mimir only;
      # OPNsense must also pass VLAN20 (mimir 10.0.20.83) -> 10.0.40.2:45876. KEY
      # is the hub's PUBLIC key (same string as the WS env files), so no sops.
      beszel.agent = {
        enable = true;
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
        trustedHubs = ["10.0.20.83"];
      };
      caddy = {
        enable = true;
        virtualHosts.${headscaleHost}.extraConfig = ''
          reverse_proxy http://${headscaleUpstream}
        '';
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
    "/var/lib/acme"
    "/var/lib/caddy"
    "/var/lib/private/ddclient"
  ];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
