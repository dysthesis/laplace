{
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs) callPackage;
  overlay = _final: _prev: {
    scripts = {
      bemenu-zk = callPackage ./bemenu-zk {inherit lib pkgs;};
      bemenu-sys = callPackage ./bemenu-sys {inherit lib pkgs;};
    };
  };
in {
  nixpkgs.overlays = [overlay];
}
