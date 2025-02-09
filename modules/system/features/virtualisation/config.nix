{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.virtualisation;
in {
  config = mkIf cfg.enable {
    virtualisation = {
      spiceUSBRedirection.enable = true;

      libvirtd = {
        enable = true;

        # Maybe this is what was slowing down shutdowns
        parallelShutdown = 10;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = true; # TODO figure out how to make it work when this is set to false.
          swtpm.enable = true;

          ovmf = {
            enable = true;
            packages = [pkgs.OVMFFull.fd];
          };
        };

        onBoot = "ignore";
        onShutdown = "shutdown";
      };
    };
    services.spice-vdagentd.enable = true;

    programs.virt-manager.enable = true;

    environment.systemPackages = with pkgs; [
      virt-manager
      virt-viewer
      qemu_kvm
      qemu
    ];

    # this allows libvirt to use pulseaudio socket
    # which is useful for virt-manager
    services.pulseaudio.extraConfig = ''
      load-module module-native-protocol-unix auth-group=qemu-libvirtd socket=/tmp/pulse-socket
    '';
  };
}
