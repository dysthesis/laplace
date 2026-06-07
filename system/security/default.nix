{lib, ...}: let
  inherit (lib.laplace.modules) importInDirectory;
in {
  # disable coredump that could be exploited later
  # and also slow down the system when something crash
  systemd.coredump.enable = false;
  imports = importInDirectory ./.;
}
