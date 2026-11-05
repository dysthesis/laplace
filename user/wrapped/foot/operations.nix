{
  pkgs,
  lib,
  foot,
}: let
  executable = lib.getExe foot;
  withAppId = pkgs.writeShellScript "foot-execute-with-app-id" ''
    app_id="$1"
    shift
    exec ${lib.escapeShellArg executable} --app-id="$app_id" -e "$@"
  '';
in {
  package = foot;
  launch = [executable];
  appId = "foot";
  execute = [executable "-e"];
  executeWithAppId = ["${withAppId}"];
}
