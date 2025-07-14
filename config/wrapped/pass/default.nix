{
  pkgs,
  lib,
  pass-wayland,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
in
  mkWrapper pkgs pass-wayland
  /*
  bash
  */
  ''
    wrapProgram $out/bin/pass \
      --set PASSWORD_STORE_DIR "/home/demiurge/.local/share/password-store"
  ''
