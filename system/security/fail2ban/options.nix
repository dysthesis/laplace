{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.security.fail2ban.enable = mkEnableOption "Whether or not to enable fail2ban";
}
