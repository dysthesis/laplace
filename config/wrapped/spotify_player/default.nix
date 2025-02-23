{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
in
mkWrapper pkgs pkgs.spotify-player ''
  wrapProgram $out/bin/spotify_player \
   --add-flags "-c ${./config}"
''
