{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.laplace.virtualisation;
in {
  options.laplace.virtualisation.enable = mkEnableOption "Whether or not to enable virtualisation capabilities";
  config = mkIf cfg.enable {
    mnemosyne.dirs = ["/var/lib/libvirt"];

    virtualisation = {
      spiceUSBRedirection.enable = true;

      libvirtd = {
        enable = true;

        # host shutdowns were slow; suspected serial VM teardown
        parallelShutdown = 10;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = true; # TODO figure out how to make it work when this is set to false.
          swtpm.enable = true;
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
