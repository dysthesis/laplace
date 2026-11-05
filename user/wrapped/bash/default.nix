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
    session = config.laplace.wm;
    startDisplay = optionalString (session != null) ''
      if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
        exec ${lib.escapeShellArgs session.login}
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
