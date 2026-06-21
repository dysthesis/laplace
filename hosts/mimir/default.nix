# Miniflux + SilverBullet + Vikunja host, running as a Proxmox guest. Generic VM concerns
# (disk, impermanence, bootloader, virtio, qemuGuest, the archon admin user, the
# VMA artifact) live in the `proxmox` profile; this module only declares the app
# apps.
#
# TLS terminates on the node-local Caddy. Apps bind loopback; only Caddy reaches
# their raw ports, and :443 is tailnet-only via laplace.services.tailscale.
{
  lib,
  pkgs,
  ...
}: let
  minifluxHost = "miniflux.dysthesis.com";
  vikunjaHost = "tasks.dysthesis.com";
in {
  # miniflux_admin lives in mimir's own sops file (moved out of the shared
  # secrets.yaml); the miniflux module declares the secret against the default
  # file, so repoint it.
  sops.secrets.miniflux_admin.sopsFile = ../../system/secrets/mimir.yaml;

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.83/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 2;
      memory = 3072; # MiB, ballooning ceiling
      balloon = 1024; # MiB, ballooning floor (Postgres + three app processes)
      diskSize = "32G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      tailscale.enable = true;
      miniflux.enable = true;
      silverbullet.enable = true;
      vikunja.enable = true;

      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false; # tailnet-only; :443 reached over tailscale0
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/cloudflare.yaml;
          proxies = {
            "miniflux.dysthesis.com" = "localhost:8087";
            "silverbullet.dysthesis.com" = "localhost:8101";
            "tasks.dysthesis.com" = "localhost:3456";
          };
        };
      };
    };
  };

  services = {
    miniflux.config = {
      LISTEN_ADDR = lib.mkForce "127.0.0.1:8087";
      # Miniflux bakes BASE_URL into absolute links + cookie scope, so it must
      # match the public origin Caddy serves, not the module's bare-localhost
      # default.
      BASE_URL = lib.mkForce "https://${minifluxHost}";
    };
    silverbullet.listenAddress = lib.mkForce "127.0.0.1";

    # Vikunja bakes publicurl into the frontend's API base; force it to the
    # public origin Caddy serves, not the module's localhost default. Stays
    # loopback-bound, Tailnet-only.
    vikunja = {
      frontendScheme = lib.mkForce "https";
      frontendHostname = lib.mkForce vikunjaHost;
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
