{
  config,
  pkgs,
  ...
}: {
  sops.secrets.beszel_agent_env.sopsFile = ../../system/secrets/loki.yaml;

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
  };

  # VLAN 20, the app segment (mneme .81, hermes .82, mimir .83). This host takes
  # .84; confirm against IPAM before deploying.
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
      beszel.agent = {
        enable = true;
        hubUrl = "https://status.dysthesis.com";
        environmentFile = config.sops.secrets.beszel_agent_env.path;
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
