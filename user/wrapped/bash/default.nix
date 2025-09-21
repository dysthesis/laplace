{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib.babel.pkgs) mkWrapper;
  inherit (builtins) elem;
  inherit (lib) optionalString;

  configuration = let
    startWayland = ''
      exec $(${lib.getExe inputs.status.packages.${pkgs.system}.default} | ${lib.getExe pkgs.configured.dwl})
    '';
    startXorg = "exec ${pkgs.configured.xinit}/bin/startx";
    startDisplay =
      # sh
      ''
        if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
         ${optionalString (elem "wayland" config.laplace.display.servers) startWayland}
         ${optionalString (elem "xorg" config.laplace.display.servers) startXorg}
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
