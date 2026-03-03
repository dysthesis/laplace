{
  inputs,
  pkgs,
  ...
}:
inputs.daedalus.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
  inherit (pkgs.configured) jjui;
  inherit (pkgs.unstable) fzf;
  shell = "${pkgs.configured.fish}/bin/fish";
  targets = [
    "~/Documents/Projects/"
    "~/Documents/University/"
  ];
}
