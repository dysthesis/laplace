{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.caddy.enable;
in {
  config = mkIf cfg {
    services.caddy = {
      enable = true;
      config = ''
      '';
    };
  };
}
