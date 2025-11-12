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
    COMP9242 = 3;
    COMP4161 = 3;
  };

  mkProjectUrgency = mapAttrsToList (
    proj: urgency: "urgency.user.project.${proj}.coefficient=${toString urgency}"
  );

  taskrc = writeText ".taskrc" ''
    ${concatStringsSep "\n" (mkProjectUrgency projectUrgency)}
    verbose=blank,footnote,label,new-id,affected,edit,special,project,sync,unwait
    weekstart=monday
    news.version=2.6.0

    search.case.sensitive=no
    data.location=~/.local/share/task

    # Prevent priority inversion
    urgency.inherit=1
    urgency.blocking.coefficient=0
    urgency.blocked.coefficient=0

    report.next.columns=id,priority,project,description,tags,due.relative,urgency
    report.next.labels=ID,Priority,Project,Description,Tags,Due,Urgency

    report.list.columns=id,priority,project,description,due.relative,urgency
    report.list.labels=ID,Priority,Project,Description,Due,Urgency

    context.home.read=+home or +computer
    context.campus.read=+campus or +computer

    # COMP3121 stuff
    alias.submit=modify wait:someday +submitted
    alias.resubmit=modify wait: -submitted

    report.awaiting.description=Submitted, awaiting feedback
    report.awaiting.columns=id,project,wait,description
    report.awaiting.sort=wait+
    report.awaiting.filter=(wait>now or +submitted)

    hooks.location=${./hooks}

    rule.precedence.color=deleted,completed,active,keyword.,tag.,project.,overdue,scheduled,due.today,due,blocked,blocking,recurring,tagged,uda.

    # General decoration
    color.label=
    color.label.sort=
    color.alternate=on gray2
    color.header=color3
    color.footnote=color3
    color.warning=bold red
    color.error=white on red
    color.debug=color4

    # Task state
    color.completed=
    color.deleted=
    color.active=rgb555 on rgb410
    color.recurring=rgb013
    color.scheduled=on rgb001
    color.until=
    color.blocked=white on color8
    color.blocking=black on color15

    # Project
    color.project.none=

    # Priority
    color.uda.priority.H=color255
    color.uda.priority.L=color245
    color.uda.priority.M=color250

    # Tags
    color.tag.next=rgb440
    color.tag.none=
    color.tagged=

    # Due
    color.due.today=rgb400
    color.due=color1
    color.overdue=color9

    # Report: burndown
    color.burndown.done=on rgb010
    color.burndown.pending=on color9
    color.burndown.started=on color11

    # Report: history
    color.history.add=color0 on rgb500
    color.history.delete=color0 on rgb550
    color.history.done=color0 on rgb050

    # Report: summary
    color.summary.background=white on color0
    color.summary.bar=black on rgb141

    # Command: calendar
    color.calendar.due.today=color15 on color1
    color.calendar.due=color0 on color1
    color.calendar.holiday=color0 on color11
    color.calendar.scheduled=
    color.calendar.overdue=color0 on color9
    color.calendar.today=color15 on rgb013
    color.calendar.weekend=on color235
    color.calendar.weeknumber=rgb013

    # Command: sync
    color.sync.added=rgb010
    color.sync.changed=color11
    color.sync.rejected=color9

    # Command: undo
    color.undo.after=color2
    color.undo.before=color1
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
