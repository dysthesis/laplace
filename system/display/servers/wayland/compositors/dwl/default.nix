{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  cfg = config.laplace.display;
  enabled = elem "wayland" cfg.servers && cfg.wayland.compositor == "dwl";
  system = pkgs.stdenv.hostPlatform.system;
in {
  config = lib.mkIf enabled {
    laplace.display.wayland.sessionCommand = "${lib.getExe inputs.status.packages.${system}.default} | ${lib.getExe' pkgs.configured.dwl "dwl"}";
    laplace.display.checkCommands = [
      ''
        test -x ${lib.getExe' pkgs.configured.dwl "dwl"}
      ''
    ];
  };
}
