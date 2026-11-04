{
  pkgs,
  bemenu,
  fd,
  gnused,
  foot,
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
    foot
    jq
    pandoc
    uutils-coreutils-noprefix
    zk
  ];
  text = builtins.readFile ./script.sh;
}
