{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.nh;
in
{
  config = mkIf cfg.enable {
    environment.sessionVariables.FLAKE = cfg.flakePath;

    environment.systemPackages = [ pkgs.nh ];
  };
}
