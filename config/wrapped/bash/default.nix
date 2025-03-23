{
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (inputs.gungnir.packages.${pkgs.system}) dwl;
  config = pkgs.writeText "bash.bashrc" ''
    if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
       dbus-update-activation-environment --systemd --all
       exec ${lib.getExe dwl}
     fi
     if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]; then
       shopt -q login_shell && LOGIN_OPTION="--login" || LOGIN_OPTION=""
       exec ${lib.getExe pkgs.configured.fish} $LOGIN_OPTION
     fi
  '';
in
  mkWrapper pkgs pkgs.bash ''
    wrapProgram $out/bin/bash \
     --add-flags '--rcfile' --add-flags '${config}'
  ''
