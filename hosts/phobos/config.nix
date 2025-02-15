{ pkgs, ... }:
let
  inherit (pkgs)
    linuxPackagesFor
    linuxKernel
    ;
in
{
  config = {
    laplace = {
      hardware = {
        cpu = [ "amd" ];
        gpu = [ "amd" ];
        monitors = [
          {
            name = "eDP";
            width = 2256;
            height = 1504;
            refreshRate = 60;
            pos = {
              x = 0;
              y = 0;
            };
          }
        ];
      };

      bootloader = "systemd-boot";

      network = {
        bluetooth.enable = true;
        wifi.enable = true;
        dnscrypt-proxy.enable = true;
      };

      security = {
        privesc = "doas";
        apparmor.enable = true;
        polkit.enable = true;
        secure-boot.enable = false;
        firewall.enable = true;
      };

      sound = {
        enable = true;
        server = "pipewire";
      };

      impermanence.enable = true;
      zram.enable = true;

      display = [ "xorg" ];
      users = [ "demiurge" ];
      virtualisation.enable = true;
      nh = {
        enable = true;
        flakePath = "~/Documents/Projects/laplace";
      };
    };
    mnemosyne.enable = true;
    boot.kernelPackages = linuxPackagesFor linuxKernel.kernels.linux_xanmod_latest;
  };
}
