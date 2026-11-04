{
  pkgs,
  gawk,
  uutils-coreutils-noprefix,
  bemenu,
  procps,
  slock,
  systemd,
  ...
}:
pkgs.writeShellApplication {
  name = "bemenu-sys";
  bashOptions = [];
  runtimeInputs = [
    gawk
    uutils-coreutils-noprefix
    bemenu
    procps
    slock
    systemd
  ];
  text = builtins.readFile ./script.sh;
}
