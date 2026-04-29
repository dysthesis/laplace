{pkgs, ...}: let
  python = pkgs.python311;
in
  pkgs.writeShellApplication {
    name = "weather";
    text = ''
      exec ${python}/bin/python ${./weather.py} "$@"
    '';
  }
