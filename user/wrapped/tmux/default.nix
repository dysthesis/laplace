{
  inputs,
  pkgs,
  ...
}:
inputs.daedalus.packages.${pkgs.system}.default.override {
  inherit (pkgs.configured) jjui;
  fzf = pkgs.unstable.skim;
  shell = "${pkgs.configured.fish}/bin/fish";
  targets = [
    "~/Documents/Projects/"
    "~/Documents/University/"
  ];
}
