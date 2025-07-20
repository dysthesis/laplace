{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) makeBinPath;
  inherit (lib.babel.pkgs) mkWrapper;
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
  ytfzf = pkgs.ytfzf.override {
    inherit (pkgs.configured)
      mpv
      ;
  };
in
mkWrapper pkgs ytfzf ''
  wrapProgram $out/bin/ytfzf \
  --set PATH ${makeBinPath dependencies} \
  --set XDG_CONFIG_HOME ${./config}
''
