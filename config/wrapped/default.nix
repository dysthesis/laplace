{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (pkgs) callPackage;
  overlay = _final: _prev: let
    guiPackage = package: package.config.env;
  in {
    configured = {
      fish = callPackage ./fish {
        inherit (pkgs) fish;
        inherit pkgs inputs lib;
      };
      bash = callPackage ./bash {inherit pkgs lib;};
      ytfzf = callPackage ./ytfzf {inherit lib pkgs;};
      zathura = callPackage ./zathura {inherit lib pkgs;};
      dunst = callPackage ./dunst {inherit lib pkgs;};
      timewarrior = callPackage ./timewarrior {inherit lib pkgs;};
      xinit = callPackage ./xinit {
        inherit
          inputs
          lib
          pkgs
          config
          ;
      };
      mpv = callPackage ./mpv {inherit lib pkgs;};
      ghostty = callPackage ./ghostty {inherit inputs lib pkgs config;};
      ani-cli = callPackage ./ani-cli {inherit pkgs;};
      spotify_player = callPackage ./spotify_player {inherit lib pkgs;};
      taskwarrior = callPackage ./taskwarrior {inherit lib pkgs;};
      taskwarrior-tui = callPackage ./taskwarrior-tui {inherit lib pkgs;};
      weechat = callPackage ./weechat {inherit lib pkgs;};
      zen = guiPackage (
        callPackage ./zen {
          inherit
            lib
            pkgs
            config
            inputs
            ;
        }
      );
      vesktop = guiPackage (
        callPackage ./vesktop {
          inherit
            lib
            pkgs
            inputs
            config
            ;
        }
      );
    };
  };
in {
  nixpkgs.overlays = [overlay];
}
