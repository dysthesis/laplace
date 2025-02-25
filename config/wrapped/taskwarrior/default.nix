{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs) writeText;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (builtins) concatStringsSep;

  projectUrgency = {
    COMP3121 = 3;
    COMP3900 = 2;
    COMP4920 = 2;
    University = 2;
  };
  mkProjectUrgency = mapAttrsToList (proj: urgency: "urgency.user.project.${proj}.coefficient=${toString urgency}");

  taskrc = writeText ".taskrc" ''
    ${concatStringsSep "\n" (mkProjectUrgency projectUrgency)}
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
