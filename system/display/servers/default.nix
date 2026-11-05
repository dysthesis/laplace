{
  lib,
  desktopSelection,
  ...
}: let
  inherit (desktopSelection) wm;
in {
  imports = lib.optionals (wm != null) [
    wm.module
    (
      if wm.protocol == "wayland"
      then ./wayland
      else ./xorg
    )
  ];

  # Selected sessions contribute their own validation commands.
  options.laplace.display.checkCommands = lib.mkOption {
    type = lib.types.listOf lib.types.lines;
    default = [];
    internal = true;
    description = "Validation snippets run by the flake's desktop-stack check.";
  };

  config =
    if wm == null
    then {laplace.wm = null;}
    else {
      location = {
        latitude = 33.9;
        longitude = 151.2;
      };
      assertions = [
        {
          assertion = desktopSelection.terminal == ../../../user/wrapped/foot/operations.nix;
          message = "Managed desktops currently support only the Foot terminal operation adapter.";
        }
      ];
    };
}
