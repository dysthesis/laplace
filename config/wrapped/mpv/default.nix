{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  mpv = pkgs.mpv.override {
    scripts = builtins.attrValues {
      inherit
        (pkgs.mpvScripts)
        sponsorblock
        thumbfast
        mpv-webm
        uosc
        ;
    };
  };
in
  mkWrapper pkgs mpv ''
    wrapProgram $out/bin/mpv \
     --add-flags '--config-dir=${./config}'
  ''
