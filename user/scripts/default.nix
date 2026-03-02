{
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs) callPackage;
  overlay = _final: _prev: {
    scripts = {
      bemenu-zk = callPackage ./bemenu-zk {
        inherit lib pkgs;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
        foot = pkgs.configured.foot;
      };
      bemenu-sys = callPackage ./bemenu-sys {
        inherit lib pkgs;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
      };
      bemenu-bib = callPackage ./bemenu-bib {
        inherit lib pkgs;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
        foot = pkgs.configured.foot;
      };
      zk-capture = callPackage ./zk-capture {
        inherit lib pkgs;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
        foot = pkgs.configured.foot;
      };
      zk-journal = callPackage ./zk-journal {
        inherit lib pkgs;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
        foot = pkgs.configured.foot;
      };
      generate-commit = callPackage ./generate-commit {
        inherit lib pkgs;
        inherit (pkgs.unstable) uutils-coreutils-noprefix;
      };
    };
  };
in {
  nixpkgs.overlays = [overlay];
}
