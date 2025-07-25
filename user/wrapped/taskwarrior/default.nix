{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (pkgs) writeText;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (builtins) concatStringsSep;

  projectUrgency = {
    COMP3121 = 3;
    COMP6453 = 3;
    COMP2041 = 2;
  };
  mkProjectUrgency = mapAttrsToList (
    proj: urgency: "urgency.user.project.${proj}.coefficient=${toString urgency}"
  );

  taskrc = writeText ".taskrc" ''
    ${concatStringsSep "\n" (mkProjectUrgency projectUrgency)}
    verbose=blank,footnote,label,new-id,affected,edit,special,project,sync,unwait
    weekstart=monday
    news.version=2.6.0
    data.location=~/.local/share/task
    hooks.location=${./hooks}
  '';
  deps = with pkgs; [
    configured.timewarrior
    python3
  ];
in
mkWrapper pkgs pkgs.taskwarrior
  # bash
  ''
    wrapProgram $out/bin/task \
     --set TASKRC ${taskrc} \
     --prefix PATH ":" "${lib.makeBinPath deps}"
  ''
