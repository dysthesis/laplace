{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  deps = with pkgs; [configured.timewarrior];
in
  mkWrapper pkgs pkgs.timewarrior ''
    wrapProgram $out/bin/task \
     --set XDG_CONFIG_HOME ${./config} \
    --prefix PATH ":" "${lib.makeBinPath deps}"
  ''
