{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.ssh.enable = mkEnableOption "Whether or not to use an SSH server";
}
