{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs) writeText;
  taskrc = writeText ".taskrc" ''
    verbose=blank,footnote,label,new-id,affected,edit,special,project,sync,unwait
     weekstart=monday
     news.version=2.6.0
     data.location=~/.local/share/task
  '';
in
  mkWrapper pkgs pkgs.taskwarrior ''
    wrapProgram $out/bin/task \
     --set TASKRC ${taskrc} \
  ''
