{
  pkgs,
  lib,
  git,
  zk,
  uutils-coreutils-noprefix,
  terminal,
  gnused,
  neovim,
  ...
}:
pkgs.writeShellApplication {
  name = "zk-capture";
  bashOptions = [];
  runtimeInputs = [
    git
    zk
    uutils-coreutils-noprefix
    gnused
    neovim
  ];
  text =
    builtins.replaceStrings
    ["@terminalExecuteWithAppId@"]
    [(lib.escapeShellArgs terminal.executeWithAppId)]
    (builtins.readFile ./script.sh);
}
