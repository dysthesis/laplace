{
  self,
  inputs,
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (pkgs) callPackage;
  inherit (lib) makeOverridable;
  overlay = _final: _prev: let
    guiPackage = package: package.config.env;
  in {
    configured = {
      read = callPackage ./read {
        inherit lib pkgs;
        inherit (inputs.read.packages.${pkgs.system}) read;
      };
      pass = callPackage ./pass {inherit lib pkgs;};
      neomutt = callPackage ./neomutt {inherit lib pkgs;};
      zk = callPackage ./zk {inherit lib pkgs;};
      helix = callPackage ./helix {inherit lib pkgs;};
      fzf = callPackage ./fzf {inherit lib pkgs;};
      btop = callPackage ./btop {inherit pkgs lib;};
      irssi = callPackage ./irssi {inherit config pkgs lib;};
      todo-txt-cli = callPackage ./todo-txt {};
      river = callPackage ./river {inherit pkgs lib;};
      waybar = callPackage ./waybar {inherit config pkgs lib;};
      hyprland = callPackage ./hyprland {inherit pkgs lib config;};
      sway = callPackage ./sway {inherit pkgs lib config;};
      bibata-hyprcursor = callPackage ./bibata-hyprcursor {};
      jujutsu = callPackage ./jujutsu {inherit pkgs lib;};
      newsraft = callPackage ./newsraft {inherit pkgs lib;};
      fish = callPackage ./fish {
        inherit (pkgs) fish;
        inherit pkgs inputs lib;
      };
      bemenu = callPackage ./bemenu {inherit pkgs config lib;};
      yambar = makeOverridable callPackage ./yambar {
        inherit pkgs lib;
        cacheDir = "/home/demiurge/.cache/dwl_info";
      };
      bash = callPackage ./bash {
        inherit
          self
          pkgs
          lib
          inputs
          config
          ;
      };
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
      ghostty = callPackage ./ghostty {
        inherit
          inputs
          lib
          pkgs
          config
          ;
      };
      ani-cli = callPackage ./ani-cli {inherit pkgs;};
      spotify-player = callPackage ./spotify_player {inherit lib pkgs;};
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
