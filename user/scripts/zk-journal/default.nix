{
  pkgs,
  gawk,
  zk,
  uutils-coreutils-noprefix,
  foot,
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
    foot
    neovim
  ];
  text = builtins.readFile ./script.sh;
}
