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
    environment.sessionVariables.NH_FLAKE = cfg.flakePath;

    environment.systemPackages = [ pkgs.nh ];
  };
}
