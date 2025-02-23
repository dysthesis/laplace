{ pkgs, ... }:
pkgs.ani-cli.override {
  mpv = pkgs.configured.mpv;
}
