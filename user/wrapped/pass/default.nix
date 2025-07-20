{
  pkgs,
  lib,
  pass,
  ...
}:
let
  passBuild = pass.override {
    waylandSupport = true;
    x11Support = false;
    dmenuSupport = false;
  };
  inherit (lib.babel.pkgs) mkWrapper;
in
mkWrapper pkgs passBuild
  # bash
  ''
    wrapProgram $out/bin/pass \
      --set PASSWORD_STORE_DIR "/home/demiurge/.local/share/password-store"
  ''
