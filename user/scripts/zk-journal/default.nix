{
  pkgs,
  lib,
  gawk,
  zk,
  uutils-coreutils-noprefix,
  terminal,
  neovim,
  ...
}:
pkgs.writeShellApplication {
  name = "zk-journal";
  bashOptions = [];
  runtimeInputs = [
    gawk
    zk
    uutils-coreutils-noprefix
    neovim
  ];
  text =
    builtins.replaceStrings
    ["@terminalExecuteWithAppId@"]
    [(lib.escapeShellArgs terminal.executeWithAppId)]
    (builtins.readFile ./script.sh);
}
