{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  inherit (builtins) elem;
  inherit (lib) optionalString;

  configuration = let
    # Do not interpolate null session commands before the selector assertions.
    waylandSession = config.laplace.display.wayland.sessionCommand;
    xorgSession = config.laplace.display.xorg.sessionCommand;
    startWayland = ''
      exec ${waylandSession}
    '';
    startXorg = "exec ${xorgSession}";
    startDisplay = ''
      if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
       ${optionalString (elem "wayland" config.laplace.display.servers && waylandSession != null) startWayland}
       ${optionalString (elem "xorg" config.laplace.display.servers && xorgSession != null) startXorg}
      fi
    '';
    startFish = ''
      case "$-" in
        *i*)
          if [ -z "$BASH_NO_FISH" ]; then
            export SHELL='${lib.getExe pkgs.configured.fish}'
            exec ${lib.getExe pkgs.configured.fish}
          fi
          ;;
      esac
    '';
  in
    pkgs.writeText "bash.bashrc"
    ''
      ${optionalString (elem "desktop" config.laplace.profiles) startDisplay}
      ${startFish}
    '';
in
  mkWrapper pkgs pkgs.bash {
    addFlags = [
      "--rcfile"
      configuration
    ];
  }
