{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  nixosConfig = config;
  settings = import ./config.nix {inherit pkgs lib config;};
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
  mkWrapper pkgs pkgs.waybar {
    addFlags = [
      "-c ${generated.json}"
      "-s ${generated.css}"
    ];
  }
