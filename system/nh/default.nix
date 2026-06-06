{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption;
  inherit (lib.types) str;
  cfg = config.laplace.nh;
in {
  options.laplace.nh = {
    enable = mkEnableOption "Whether or not to enable nh";
    flakePath = mkOption {
      type = str;
      description = "Path to the flake with the NixOS configuration";
    };
  };
  config = mkIf cfg.enable {
    environment.sessionVariables.NH_FLAKE = cfg.flakePath;

    environment.systemPackages = [pkgs.nh];
  };
}
