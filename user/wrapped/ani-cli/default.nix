{pkgs, ...}:
pkgs.unstable.ani-cli.override {
  mpv = pkgs.configured.mpv;
}
