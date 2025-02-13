{ config, lib, pkgs, ... }:
let inherit (lib) fold toLower;
in {
  home.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
  programs.ghostty = {
    enable = true;
    installVimSyntax = true;
    installBatSyntax = config.programs.bat.enable;
    # Get ghostty to work with the hardened kernel
    # From https://github.com/ghostty-org/ghostty/discussions/3267#discussioncomment-11676232
    package = pkgs.ghostty.overrideAttrs (old: {
      preBuild = (old.preBuild or "") +
        # bash
        ''
          shopt -s globstar
          sed -i 's/^const xev = @import("xev");$/const xev = @import("xev").Epoll;/' **/*.zig
          shopt -u globstar
        '';
    });
    settings = rec {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 9;
      window-padding-x = 20;
      window-padding-y = 20;
      adjust-cell-height = "20%";
      font-feature = [
        "calt"
        "clig"
        "liga"
        "ss20"
        "cv02"
        "cv03"
        "cv04"
        "cv05"
        "cv06"
        "cv07"
        "cv11"
        "cv14"
        "cv15"
        "cv16"
        "cv17"
      ];
      palette = [
        "0=#080808"
        "1=#d70000"
        "2=#789978"
        "3=#ffaa88"
        "4=#7788aa"
        "5=#d7007d"
        "6=#708090"
        "7=#deeeed"
        "8=#444444"
        "9=#d70000"
        "10=#789978"
        "11=#ffaa88"
        "12=#7788aa"
        "13=#d7007d"
        "14=#708090"
        "15=#deeeed"

      ];
      background = "#000000";
      foreground = "#ffffff";
      cursor-color = foreground;
      selection-background = "#7a7a7a";
      selection-foreground = "#0a0a0a";
    };
  } # Automatically enable integration with any enabled shells
    // fold (curr: acc:
      acc // {
        "enable${curr}Integration" = config.programs.${toLower curr}.enable;
      }) { } [ "Zsh" "Bash" "Fish" ];
}
