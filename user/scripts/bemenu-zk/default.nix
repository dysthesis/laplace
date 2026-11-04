{
  pkgs,
  gawk,
  zk,
  uutils-coreutils-noprefix,
  foot,
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
    foot
    bemenu
  ];
  text = builtins.readFile ./script.sh;
}
