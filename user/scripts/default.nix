{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (pkgs) callPackage;
  desktop = config.laplace.desktop;
  terminal =
    (
      if desktop == null
      then lib.components.foot
      else desktop.term
    ).build {
      inherit pkgs lib;
      foot = pkgs.configured.foot;
    };
  overlay = _final: _prev: {
    scripts = {
      bemenu-zk = callPackage ./bemenu-zk {
        inherit lib pkgs terminal;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
      };
      bemenu-sys = callPackage ./bemenu-sys {
        inherit lib pkgs;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
      };
      bemenu-bib = callPackage ./bemenu-bib {
        inherit lib pkgs terminal;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
      };
      zk-capture = callPackage ./zk-capture {
        inherit lib pkgs terminal;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
      };
      zk-journal = callPackage ./zk-journal {
        inherit lib pkgs terminal;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
      };
      generate-commit = callPackage ./generate-commit {
        inherit pkgs;
      };
    };
  };
in {
  nixpkgs.overlays = [overlay];
}
