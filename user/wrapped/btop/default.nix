{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  deps = with pkgs; [rocmPackages.rocm-smi];
in
  mkWrapper pkgs pkgs.unstable.btop-rocm
  # sh
  ''
    wrapProgram $out/bin/btop \
     --prefix PATH ":" "${lib.makeBinPath deps}"
  ''
