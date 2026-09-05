{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) makeBinPath;
  inherit (lib.laplace.pkgs) mkWrapper;
  dependencies = with pkgs; [
    configured.mpv
    gnugrep
    gawk
    findutils
    diffutils
    unixtools.column
    yt-dlp
    ueberzugpp
    unstable.fzf
    jq
    ncurses
    curl
  ];
  ytfzf =
    (pkgs.ytfzf.override {
      inherit (pkgs.configured) mpv;
      inherit (pkgs.unstable) fzf;
    }).overrideAttrs (old: {
      patches =
        (old.patches or [])
        ++ [
          ./youtube-thumbnail.patch
        ];
    });
in
  # PATH is *replaced* (not prefixed): ytfzf shells out to a fixed toolset.
  mkWrapper pkgs ytfzf {
    set = {
      PATH = makeBinPath dependencies;
      XDG_CONFIG_HOME = "${./config}";
    };
  }
