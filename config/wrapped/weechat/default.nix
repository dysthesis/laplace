{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
in
mkWrapper pkgs pkgs.weechat ''
  wrapProgram $out/bin/weechat \
    --add-flags "-d ${./config}"
''
