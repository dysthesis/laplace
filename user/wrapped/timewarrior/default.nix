{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.laplace.pkgs) mkWrapper;
  deps = with pkgs; [python3];
in
  mkWrapper pkgs pkgs.timewarrior ''
    wrapProgram $out/bin/timew \
     --set TIMEWARRIORDB /home/demiurge/.local/share/timewarrior \
     --prefix PATH ":" "${lib.makeBinPath deps}"
  ''
