{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (pkgs) callPackage;
  overlay =
    _final: _prev:
    let
      zen = callPackage ./zen {
        inherit
          lib
          pkgs
          config
          inputs
          ;
      };
    in
    {
      configured = {
        fish = callPackage ./fish {
          inherit (pkgs) fish;
          inherit pkgs inputs lib;
        };
        bash = callPackage ./bash { inherit pkgs lib; };
        ytfzf = callPackage ./ytfzf { inherit lib pkgs; };
        zathura = callPackage ./zathura { inherit lib pkgs; };
        dunst = callPackage ./dunst { inherit lib pkgs; };
        xinit = callPackage ./xinit { inherit inputs lib pkgs; };
        mpv = callPackage ./mpv { inherit lib pkgs; };
        ghostty = callPackage ./ghostty { inherit inputs lib pkgs; };
        ani-cli = callPackage ./ani-cli { inherit pkgs; };
        spotify_player = callPackage ./spotify_player { inherit lib pkgs; };
        zen = zen.config.env;
      };
    };
in
{
  nixpkgs.overlays = [ overlay ];
}
