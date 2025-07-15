{
  hyprlock,
  lib,
  ...
}: let
  timeout = 300;
in {
  general.lock_cmd = "${lib.getExe hyprlock}";

  listener = [
    {
      inherit timeout;
      on-timeout = "hyprctl dispatch dpms off";
      on-resume = "hyprctl dispatch dpms on";
    }
    {
      timeout = timeout + 10;
      on-timeout = "${lib.getExe hyprlock}";
    }
  ];
}
