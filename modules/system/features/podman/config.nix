{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.podman;
in {
  config = mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      autoPrune = {
        enable = true;
        flags = ["-af"];
      };
      extraPackages = with pkgs; [gvisor];
    };
  };
}
