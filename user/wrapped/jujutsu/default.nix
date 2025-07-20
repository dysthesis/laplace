{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs.writers) writeTOML;
  config = writeTOML "jujutsu-config" (import ./config.nix { inherit pkgs lib; });
in
mkWrapper pkgs pkgs.jujutsu ''
  wrapProgram $out/bin/jj \
    --set JJ_CONFIG ${config}
''
