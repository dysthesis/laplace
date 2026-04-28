{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  nixosConfig = config;
  settings = import ./config.nix {inherit lib config;};
  weather = import ./weather.nix {inherit pkgs;};
  generated = import ./generator.nix {
    inherit
      pkgs
      lib
      settings
      weather
      ;
    hostName = nixosConfig.networking.hostName or "";
    monitors = nixosConfig.laplace.hardware.monitors or [];
  };
in
  mkWrapper pkgs pkgs.waybar
  # sh
  ''
    wrapProgram $out/bin/waybar \
      --add-flags "-c ${generated.json}" \
      --add-flags "-s ${generated.css}"
  ''
