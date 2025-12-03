{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) makeBinPath;
  inherit (lib.babel.pkgs) mkWrapper;
  deps = with pkgs; [
    libnotify
  ];
in
  mkWrapper pkgs pkgs.newsraft ''
    wrapProgram $out/bin/newsraft \
      --prefix PATH ":" ${makeBinPath deps} \
      --add-flags "-c ${./config}" \
      --add-flags "-f ${./feeds}"
  ''
