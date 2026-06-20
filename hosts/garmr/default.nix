{pkgs, ...}: {
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      # Linkwarden = Next.js server + worker + Postgres + a headless Chromium it
      # spawns to archive each link (screenshot/PDF/singlefile). Chromium is the
      # spike: ~0.5-1 GiB per archive on top of node/postgres, so 4 GiB gives it
      # headroom (root tmpfs takes 50% of RAM = 2 GiB; zram cushions the rest).
      # simplification: bulk-archiving large batches can still pressure RAM;
      # upgrade path is bump memory to 6144/8192 if Chromium starts OOMing.
      cores = 2;
      memory = 4096; # MiB
      # Archives (PDF + screenshot + singlefile HTML per link) accumulate in
      # /var/lib/linkwarden on the btrfs /nix/persist; 100G holds tens of
      # thousands of pages. Bump if the archive grows past that.
      diskSize = "100G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      linkwarden.enable = true;
      # Required: linkwarden is tailnet-only (port firewalled, reachable solely
      # over the tailscale0-trusted interface). Asserted by the linkwarden module.
      tailscale.enable = true;
      # First-run note: upstream disables registration, which locks out the very
      # first signup. Set `linkwarden.enableRegistration = true` here, create the
      # initial account, then revert this to keep the (tailnet-only) instance shut.
    };
  };

  # Linkwarden's NextAuth (v4) requires NEXTAUTH_URL = the browser-facing URL,
  # and nixpkgs leaves it unset. Clients reach this instance only via Caddy on
  # horos (linkwarden.dysthesis.com, TLS terminated there, proxied over the
  # tailnet), so point it at that name + /api/v1/auth or login/CSRF breaks.
  services.linkwarden.environment.NEXTAUTH_URL = "https://linkwarden.dysthesis.com/api/v1/auth";

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.84/24";
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
