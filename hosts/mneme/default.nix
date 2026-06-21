{pkgs, ...}: {
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4;
      memory = 8096; # MiB, ballooning ceiling
      # Immich (ML models + server) + Postgres + Redis; floor well above their
      # resident set so the host never reclaims into a live photo import / ML run.
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

      # immich's own TLS frontend, colocated with the app (no central horos
      # proxy). DNS-01 because immich.dysthesis.com has no public A record. Gives
      # https://immich.dysthesis.com on mneme:443, ACL-gated per cohort at
      # immich:443. Needs the sops onboarding below before it evaluates/deploys.
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false; # tailnet-only; :443 reached over tailscale0
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/cloudflare.yaml;
          # immich binds 0.0.0.0:2283 (its module default); Caddy proxies locally.
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
