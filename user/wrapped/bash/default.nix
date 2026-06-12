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
    # Session commands are contributed by the selected compositor/session
    # modules under system/display/servers. The null checks matter: a session
    # marked broken contributes nothing, and interpolating the resulting null
    # here would otherwise throw before the broken-member assertion renders.
    waylandSession = config.laplace.display.wayland.sessionCommand;
    xorgSession = config.laplace.display.xorg.sessionCommand;
    startWayland = ''
      exec ${waylandSession}
    '';
    startXorg = "exec ${xorgSession}";
    startDisplay =
      # sh
      ''
        if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
         ${optionalString (elem "wayland" config.laplace.display.servers && waylandSession != null) startWayland}
         ${optionalString (elem "xorg" config.laplace.display.servers && xorgSession != null) startXorg}
        fi
      '';
    startFish =
      # sh
      ''
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
    # sh
    ''
      ${optionalString (elem "desktop" config.laplace.profiles) startDisplay}
      ${startFish}
    '';
in
  mkWrapper pkgs pkgs.bash ''
    wrapProgram $out/bin/bash \
     --add-flags '--rcfile' --add-flags '${configuration}'
  ''
