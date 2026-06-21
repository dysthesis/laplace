# Miniflux + SilverBullet host, running as a Proxmox guest. Generic VM concerns
# (disk, impermanence, bootloader, virtio, qemuGuest, the archon admin user, the
# VMA artifact) live in the `proxmox` profile; this module only declares the two
# apps.
#
# TLS lives elsewhere now: the central Caddy on horos terminates https for
# miniflux.dysthesis.com / silverbullet.dysthesis.com and reverse-proxies here
# over the tailnet. So both apps bind 0.0.0.0 (reachable from horos via
# tailscale0) instead of loopback, and their ports stay out of the firewall -
# laplace.services.tailscale trusts only tailscale0, so they're tailnet-only,
# never exposed on the LAN or publicly. No Caddy, cert, or Cloudflare token here.
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

      # Each app's own TLS frontend, colocated (no central horos proxy). DNS-01
      # because the names have no public A record. Both resolve to mimir now.
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

  # Rebind both apps from the module-default loopback to all interfaces so the
  # Caddy on horos can reach them over the tailnet. The ports are never added to
  # the firewall, so only tailscale0 (trusted) reaches them - same tailnet-only
  # posture as Immich/AdGuard.
  services = {
    miniflux.config = {
      LISTEN_ADDR = lib.mkForce "0.0.0.0:8087";
      # Miniflux bakes BASE_URL into absolute links + cookie scope, so it must match
      # the public origin horos serves, not the module's bare-localhost default.
      BASE_URL = lib.mkForce "https://${minifluxHost}";
    };
    silverbullet.listenAddress = lib.mkForce "0.0.0.0";

    # Vikunja bakes publicurl into the frontend's API base; force it to the public
    # origin Caddy serves, not the module's localhost default. Stays loopback-bound
    # (Caddy is colocated here), tailnet-only via Caddy's openFirewall = false.
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
