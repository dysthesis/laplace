{
  lib,
  modulesPath,
  ...
}:
let
  inherit (lib) mkForce;
in
{
  # Instead of using nixos-install, we build an image using `nix build .#nixosConfigurations.erebus.
  # config.system.build.sdImage`, and burn it to the SD card
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ./hardware.nix
  ];

  networking.stevenblack.enable = true;

  laplace = {
    harden = [ "kernel" ];
    zram.enable = true;
    network.optimise = true;
    docker.enable = true;
    network.wifi.enable = true;
    security = {
      privesc = "doas";
      firewall.enable = true;
    };
    services.cloudflared.enable = true;
    users = [ "demiurge" ];
    nh = {
      enable = true;
      flakePath = "/home/demiurge/Documents/Projects/laplace";
    };
  };
  time.timeZone = "Australia/Sydney";
  i18n.defaultLocale = "en_AU.UTF-8";
  networking.nameservers = [
    "9.9.9.9"
    "9.0.0.9"
  ];
  services.resolved = {
    enable = true;
    dnssec = "true";
    fallbackDns = [
      "9.9.9.9"
      "9.0.0.9"
    ];
    dnsovertls = "true";
  };

  boot.tmp.useTmpfs = mkForce false;
}
