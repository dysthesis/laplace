{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  deps = with pkgs; [ rocmPackages.rocm-smi ];
in
mkWrapper pkgs pkgs.unstable.btop-rocm
  # sh
  ''
    wrapProgram $out/bin/btop \
     --prefix PATH ":" "${lib.makeBinPath deps}"
  ''
