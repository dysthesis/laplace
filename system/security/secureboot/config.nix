{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.security.secure-boot.enable;
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
  config = mkIf cfg {
    environment.systemPackages = [
      # For debugging and troubleshooting Secure Boot.
      pkgs.sbctl
    ];

    boot = {
      loader.systemd-boot.enable = lib.mkForce false;
      lanzaboote = {
        # Lanzaboote currently replaces the systemd-boot module.
        # This setting is usually set to true in configuration.nix
        # generated at installation time. So we force it to false
        # for now.
        enable = true;

        pkiBundle = "/etc/secureboot";
      };
    };
  };
}
