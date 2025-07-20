{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (builtins) elem;
  inherit (lib) optionalString;
  configuration =
    let
      startDisplay =
        # sh
        ''
          if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
           exec ${lib.getExe pkgs.configured.hyprland}
          fi
        '';
    in
    pkgs.writeText "bash.bashrc"
      # sh
      ''
        ${optionalString (elem "desktop" config.laplace.profiles) startDisplay}
      '';
in
mkWrapper pkgs pkgs.bash ''
  wrapProgram $out/bin/bash \
   --add-flags '--rcfile' --add-flags '${configuration}'
''
