{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (pkgs.unstable) callPackage;
  inherit (lib) makeOverridable;
  inherit (lib.laplace.pkgs) mkWrapper;
  system = pkgs.stdenv.hostPlatform.system;
  overlay = _final: _prev: let
    guiPackage = package: package.config.env;
  in {
    configured = rec {
      headroom = callPackage ./headroom {inherit pkgs;};
      subtui = callPackage ./subtui {inherit pkgs lib;};
      opencode = callPackage ./opencode {inherit pkgs lib;};
      delta = callPackage ./delta {inherit pkgs lib;};
      gh-dash = callPackage ./gh-dash {inherit pkgs lib delta;};
      direnv = callPackage ./direnv {
        inherit pkgs lib;
        inherit (pkgs.unstable) direnv;
      };
      tmux = callPackage ./tmux {inherit inputs pkgs;};
      jjui = callPackage ./jjui {
        inherit lib pkgs jujutsu;
        inherit (pkgs) jjui;
      };
      wezterm = callPackage ./wezterm {
        inherit lib pkgs;
        inherit (pkgs.unstable) wezterm;
      };
      read = callPackage ./read {
        inherit lib pkgs;
        inherit (inputs.read.packages.${system}) read;
      };
      pi = callPackage ./pi {
        inherit lib pkgs;
      };
      serena = callPackage ./serena {
        inherit pkgs;
        serena = inputs.serena.packages.${system}.default;
      };
      pass = callPackage ./pass {inherit lib pkgs;};
      lazygit = callPackage ./lazygit {
        inherit lib pkgs;
        inherit (pkgs.scripts) generate-commit;
      };
      neomutt = callPackage ./neomutt {inherit lib pkgs;};
      zk = callPackage ./zk {inherit lib pkgs;};
      helix = callPackage ./helix {
        inherit lib pkgs;
        inherit (pkgs.unstable) helix;
        helixUnwrapped = pkgs.unstable.helix-unwrapped;
      };
      fzf = callPackage ./fzf {inherit lib pkgs;};
      rofi = callPackage ./rofi {inherit lib pkgs;};
      bmm = callPackage ./bmm {inherit lib pkgs;};
      btop = callPackage ./btop {inherit pkgs lib;};
      irssi = callPackage ./irssi {inherit config pkgs lib;};
      wikiman = callPackage ./wikiman {inherit pkgs lib;};
      todo-txt-cli = callPackage ./todo-txt {};
      river = callPackage ./river {inherit pkgs lib;};
      waybar = callPackage ./waybar {inherit config pkgs lib;};
      dwl = callPackage ./dwl {
        inherit
          config
          pkgs
          lib
          inputs
          ;
      };
      swaylock = callPackage ./swaylock {inherit lib pkgs;};
      hyprland = callPackage ./hyprland {
        inherit
          pkgs
          lib
          config
          inputs
          ;
      };
      niri = callPackage ./niri {
        inherit
          pkgs
          lib
          config
          inputs
          ;
      };
      bibiman = callPackage ./bibiman {inherit pkgs lib inputs;};
      sway = callPackage ./sway {
        inherit
          pkgs
          lib
          config
          inputs
          ;
      };
      bibata-hyprcursor = callPackage ./bibata-hyprcursor {};
      jujutsu = callPackage ./jujutsu {inherit pkgs lib;};
      newsraft = callPackage ./newsraft {inherit pkgs lib;};
      fish = callPackage ./fish {
        inherit (pkgs) fish;
        inherit pkgs inputs lib direnv;
      };
      fuzzel = let
        hostName = config.networking.hostName or "";
        fontSize =
          if hostName == "phobos"
          then 13
          else 11.5;
        configFile =
          {
            main = {
              terminal = lib.getExe foot;
              font = "IosevkaCadmus Nerd Font:size=${toString fontSize}";
              prompt = " ";
              layer = "overlay";
              lines = 12;
              width = 80;
              "horizontal-pad" = 10;
              "vertical-pad" = 8;
              "inner-pad" = 8;
            };

            colors = {
              background = "000000ee";
              text = "ffffffff";
              match = "7788aaff";
              selection = "080808ff";
              "selection-text" = "ffffffff";
              "selection-match" = "ffcc66ff";
              border = "ffffffff";
            };

            border = {
              width = 1;
              radius = 8;
            };
          }
          |> lib.generators.toINI {}
          |> pkgs.writeText "fuzzel.ini";
      in
        mkWrapper pkgs pkgs.fuzzel {addFlags = ["--config=${configFile}"];};
      bemenu = callPackage ./bemenu {inherit pkgs config lib;};
      yambar = makeOverridable callPackage ./yambar {
        inherit pkgs lib;
        cacheDir = "/home/demiurge/.cache/dwl_info";
      };
      bash = callPackage ./bash {inherit pkgs lib config;};
      ytfzf = callPackage ./ytfzf {inherit lib pkgs;};
      zathura = callPackage ./zathura {inherit lib pkgs;};
      dunst = callPackage ./dunst {inherit lib pkgs config;};
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
      foot = callPackage ./foot {
        inherit lib pkgs config;
      };
      ani-cli = callPackage ./ani-cli {inherit pkgs;};
      spotify-player = callPackage ./spotify_player {inherit lib pkgs;};
      taskwarrior = callPackage ./taskwarrior {inherit lib pkgs;};
      khal = callPackage ./khal {inherit lib pkgs;};
      vdirsyncer = callPackage ./khal/vdirsyncer.nix {inherit lib pkgs;};
      # Taskwarrior 2 compatibility pin.
      taskwarrior-tui2 = callPackage ./taskwarrior-tui {inherit lib pkgs;};
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
      zotero = guiPackage (
        callPackage ./zotero {
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
