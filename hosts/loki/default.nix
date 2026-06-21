# Dedicated Homestead Minecraft host, running as a Proxmox guest. Its only job is
# the Fabric server; everything generic (disk, impermanence, bootloader, virtio,
# qemuGuest, the archon admin user, the VMA artifact) comes from the `proxmox`
# profile, exactly like mimir/horos/bifrost.
#
# Reachable only over the tailnet: horos forwards mc.dysthesis.com (raw TCP 25565,
# not HTTP, so it bypasses Caddy via a systemd socket proxy - see horos) to this
# guest's tailnet node. The MC port is never opened on the LAN -
# laplace.services.tailscale trusts only tailscale0, so horos (a tailnet peer)
# reaches it while the LAN cannot. mc.dysthesis.com resolves to horos's tailnet IP
# via the bifrost extra_record.
#
# World migration from deimos is a one-off data copy, not config:
#   rsync deimos:/srv/minecraft/retirement-home/ loki:/srv/minecraft/retirement-home/
# before first start (the seed otherwise regenerates a fresh, identical world).
{pkgs, ...}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  # VLAN 20, the app segment (mneme .81, hermes .82, mimir .83, horos .85). .84 is
  # the free slot between them; confirm against IPAM before deploying.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.84/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
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

      minecraft.retirement-home = {
        enable = true;
        autoStart = true; # dedicated host - the server is the point
        restart = "on-failure";
        openFirewall = false; # tailnet-only; horos forwards 25565 over tailscale0
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
