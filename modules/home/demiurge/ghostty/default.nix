{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    fold
    toLower
    ;
in {
  programs.ghostty =
    {
      enable = true;
      installVimSyntax = true;
      installBatSyntax = config.programs.bat.enable;
      # Get ghostty to work with the hardened kernel
      # From https://github.com/ghostty-org/ghostty/discussions/3267#discussioncomment-11676232
      package = pkgs.ghostty.overrideAttrs (old: {
        preBuild =
          (old.preBuild or "")
          +
          # bash
          ''
            shopt -s globstar
            sed -i 's/^const xev = @import("xev");$/const xev = @import("xev").Epoll;/' **/*.zig
            shopt -u globstar
          '';
      });
      settings = {
        theme = "catppuccin-mocha";
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
      };
      themes.catppuccin-mocha = {
        background = "000000";
        foreground = "ffffff";
      };
    } # Automatically enable integration with any enabled shells
    // fold
    (curr: acc:
      acc
      // {"enable${curr}Integration" = config.programs.${toLower curr}.enable;})
    {}
    ["Zsh" "Bash" "Fish"];
}
