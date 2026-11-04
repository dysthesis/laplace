{
  pkgs,
  git,
  zk,
  uutils-coreutils-noprefix,
  foot,
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
    foot
    neovim
  ];
  text = builtins.readFile ./script.sh;
}
