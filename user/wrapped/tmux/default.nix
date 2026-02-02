{
  inputs,
  pkgs,
  ...
}:
inputs.daedalus.packages.${pkgs.system}.default.override {
  inherit (pkgs.configured) jjui;
  shell = "${pkgs.configured.fish}/bin/fish";
  targets = [
    "~/Documents/Projects/"
    "~/Documents/University/"
  ];
}
