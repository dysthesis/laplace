{pkgs, ...}: let
  python = pkgs.python311.withPackages (pythonPackages: with pythonPackages; [ftputil]);
in
  pkgs.writeShellApplication {
    name = "weather";
    text = ''
      exec ${python}/bin/python ${./weather.py} "$@"
    '';
  }
