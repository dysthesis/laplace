{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) makeBinPath;
  inherit (lib.babel.pkgs) mkWrapper;
  dependencies = with pkgs; [
    mpv
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
in
mkWrapper pkgs pkgs.ytfzf ''
  wrapProgram $out/bin/ytfzf \
  --set PATH ${makeBinPath dependencies} \
  --set XDG_CONFIG_HOME ${./config}
''
