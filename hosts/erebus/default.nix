{
  lib,
  modulesPath,
  ...
}: let
  inherit (lib) mkForce;
in {
  # Instead of using nixos-install, we build an image using `nix build .#nixosConfigurations.erebus.
  # config.system.build.sdImage`, and burn it to the SD card
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ./hardware.nix
  ];

  laplace = {
    harden = ["kernel"];
    zram.enable = true;
    docker.enable = true;
    network = {
      wifi.enable = true;
      optimise = true;
    };
    security = {
      privesc = "doas";
      firewall.enable = true;
    };
    services.cloudflared.enable = true;
    users = ["demiurge"];
    nh = {
      enable = true;
      flakePath = "/home/demiurge/Documents/Projects/laplace";
    };
  };
  time.timeZone = "Australia/Sydney";
  i18n.defaultLocale = "en_AU.UTF-8";

  services.resolved = {
    enable = true;
    dnssec = "true";
    fallbackDns = [
      "9.9.9.9"
      "9.0.0.9"
    ];
    dnsovertls = "true";
  };

  fileSystems = {
    "/mnt/data" = {
      device = "/dev/disk/by-uuid/9e58df18-7075-4baa-9ee1-dc8e8d3b3b06";
      fsType = "ext4";
      options = ["data=journal"];
    };
  };

  networking = {
    # wireless.networks."SSID".psk = "PSK";
    nameservers = [
      "9.9.9.9"
      "9.0.0.9"
    ];
    stevenblack.enable = true;
  };

  boot.tmp.useTmpfs = true;
}
