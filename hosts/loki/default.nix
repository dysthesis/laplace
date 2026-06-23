{
  config,
  pkgs,
  ...
}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.60.1"];
  };

  # VLAN 60, loki's own isolated segment (F10): the untrusted modpack box has no
  # legitimate VLAN20 peer (game served over tailscale0, Beszel is pulled over the
  # tunnel by mimir, runtime DNS is AdGuard over the tunnel). LAN reach = gateway (10.0.60.1,
  # boot DNS + NAT egress) + the workstation->:22 deploy pinhole only; heimdall DROPs
  # loki->VLAN20/30/40/50. The tailnet half of the containment is the SSOT `game` tag.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.60.2/24";
      Gateway = "10.0.60.1";
      DNS = "10.0.60.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4; # MC main-tick thread + chunk-gen/GC workers
      memory = 10240; # MiB, ballooning ceiling (10 GiB)
      balloon = 8192; # MiB, ballooning floor (8 GiB)
      diskSize = "64G"; # world + modpack; bump before a large chunk pregen
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
    };

    zram.enable = true;

    services = {
      tailscale.enable = true;
      beszel.agent = {
        enable = true;
        # SSH/pull: mimir dials IN to loki, so game cannot initiate HTTPS to the
        # hub/app vhosts on mimir. KEY is the hub's public key; no token/sops.
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
        trustedHubs = [config.laplace.tailnet.nodes.mimir.ip];
      };
      minecraft.retirement-home = {
        enable = true;
        autoStart = true; # dedicated host - the server is the point
        restart = "on-failure";
        openFirewall = false; # tailnet-only; players reach :25565 over tailscale0
        # Heap at deimos parity. The guest boots at the 10 GiB ceiling, so the
        # 8 GiB heap plus JVM non-heap and OS fits underneath; the 8 GiB balloon
        # floor only bites under host pressure, which a single-purpose node should
        # never see (earlyoom in the proxmox profile is the backstop).
        memoryGb = 8;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
    rsync
  ];
}
