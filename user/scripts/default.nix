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
      bemenu-bib = callPackage ./bemenu-bib {inherit lib pkgs;};
      zk-capture = callPackage ./zk-capture {inherit lib pkgs;};
      zk-journal = callPackage ./zk-journal {inherit lib pkgs;};
    };
  };
in {
  nixpkgs.overlays = [overlay];
}
