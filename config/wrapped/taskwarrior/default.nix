{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs) writeText;
  taskrc = writeText ".taskrc" ''
    weekstart=monday
    news.version=2.6.2
    data.location=~/.local/share/task
  '';
in
  mkWrapper pkgs pkgs.taskwarrior ''
    wrapProgram $out/bin/task \
     --set TASKRC ${taskrc} \
  ''
