{lib, ...}: let
  inherit (lib) mkOption;
in {options.laplace.security.fail2ban.enable = mkOption "Whether or not to enable fail2ban";}
