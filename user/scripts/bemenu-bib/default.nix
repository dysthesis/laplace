{
  pkgs,
  lib,
  bemenu,
  fd,
  gnused,
  terminal,
  jq,
  pandoc,
  uutils-coreutils-noprefix,
  zk,
  ...
}:
pkgs.writeShellApplication {
  name = "bemenu-bib";
  bashOptions = [];
  runtimeInputs = [
    bemenu
    fd
    gnused
    jq
    pandoc
    uutils-coreutils-noprefix
    zk
  ];
  text =
    builtins.replaceStrings
    ["@terminalExecute@"]
    [(lib.escapeShellArgs terminal.execute)]
    (builtins.readFile ./script.sh);
}
