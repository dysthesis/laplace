{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.impermanence;
  addIf = cond: content:
    if cond
    then [content]
    else [];
in {
  imports = [inputs.impermanence.nixosModule];

  config = mkIf cfg.enable {
    programs.fuse.userAllowOther = true;
    environment.persistence."${cfg.persistDir}" = {
      hideMounts = true;
      directories =
        [
          "/var/lib/nixos"
          "/etc/nixos"
          "/etc/NetworkManager"
          "/etc/ssh"
          "/etc/NetworkManager/system-connections"
        ]
        ++ addIf config.laplace.features.virtualisation.enable "/var/lib/libvirt"
        ++ addIf config.laplace.network.bluetooth.enable "/var/lib/bluetooth"
        ++ addIf config.laplace.security.secure-boot.enable "/etc/secureboot";

      files =
        ["/etc/machine-id"]
        ++ addIf config.laplace.network.dnscrypt-proxy.enable "/etc/dnscrypt-proxy/blocked-names.txt";
    };
  };
}
