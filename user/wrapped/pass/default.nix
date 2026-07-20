{
  pkgs,
  lib,
  pass,
  ...
}: let
  passBuild = pass.override {
    waylandSupport = true;
    x11Support = false;
    dmenuSupport = false;
  };
  inherit (lib.laplace.pkgs) mkWrapper;
in
  mkWrapper pkgs passBuild {set.PASSWORD_STORE_DIR = "/home/demiurge/.local/share/password-store";}
