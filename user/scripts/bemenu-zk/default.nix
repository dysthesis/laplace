{
  pkgs,
  lib,
  gawk,
  zk,
  uutils-coreutils-noprefix,
  terminal,
  bemenu,
  ...
}:
pkgs.writeShellApplication {
  name = "bemenu-zk";
  bashOptions = [];
  runtimeInputs = [
    gawk
    zk
    uutils-coreutils-noprefix
    bemenu
  ];
  text =
    builtins.replaceStrings
    ["@terminalExecute@"]
    [(lib.escapeShellArgs terminal.execute)]
    (builtins.readFile ./script.sh);
}
