{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (pkgs.unstable) callPackage;
  inherit (lib) makeOverridable;
  system = pkgs.stdenv.hostPlatform.system;
  desktop = config.laplace.desktop;
  integrated = desktop != null && desktop.shell != null;
  terminal =
    (
      if desktop == null
      then lib.components.foot
      else desktop.term
    ).build {
      inherit pkgs lib;
      foot = pkgs.configured.foot;
    };
  overlay = _final: _prev: let
    guiPackage = package: package.config.env;
  in {
    configured = rec {
      ytsub = callPackage ./ytsub {inherit pkgs lib;};
      headroom = callPackage ./headroom {inherit pkgs;};
      subtui = callPackage ./subtui {inherit pkgs lib;};
      opencode = callPackage ./opencode {inherit pkgs lib;};
      delta = callPackage ./delta {inherit pkgs lib;};
      gh-dash = callPackage ./gh-dash {inherit pkgs lib delta;};
      direnv = callPackage ./direnv {
        inherit pkgs lib;
        inherit (pkgs.unstable) direnv;
        nix = config.nix.package;
        nix-direnv = pkgs.unstable.nix-direnv.override {nix = config.nix.package;};
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
      bmm = callPackage ./bmm {inherit lib pkgs;};
      btop = callPackage ./btop {inherit pkgs lib;};
      irssi = callPackage ./irssi {inherit config pkgs lib;};
      wikiman = callPackage ./wikiman {inherit pkgs lib;};
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
      swaylock = callPackage ./swaylock {
        inherit lib pkgs integrated;
      };
      hyprland = callPackage ./hyprland {
        inherit
          pkgs
          lib
          config
          inputs
          ;
      };
      vicinae = callPackage ./vicinae {
        inherit pkgs lib;
        inherit (pkgs) vicinae;
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
      fuzzel = callPackage ./fuzzel {inherit lib pkgs config terminal;};
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
      foot = callPackage ./foot {
        inherit lib pkgs config integrated;
      };
      ani-cli = callPackage ./ani-cli {inherit pkgs;};
      taskwarrior = callPackage ./taskwarrior {inherit lib pkgs;};
      vdirsyncer = callPackage ./khal/vdirsyncer.nix {inherit lib pkgs;};
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
