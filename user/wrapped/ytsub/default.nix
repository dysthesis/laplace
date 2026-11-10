{
  lib,
  pkgs,
  ytsub,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;

  fixedYtsub = ytsub.overrideAttrs (old: {
    preBuild =
      (old.preBuild or "")
      + ''
        export AWS_LC_SYS_USE_SYSTEM=0
        echo "AWS_LC_SYS_USE_SYSTEM=$AWS_LC_SYS_USE_SYSTEM"
      '';
  });
in
  mkWrapper pkgs fixedYtsub {
    binPath = [
      pkgs.configured.mpv
    ];
  }
