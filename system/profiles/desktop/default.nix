{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  cfg = config.laplace.profiles;
in
{
  config = mkIf (elem "desktop" cfg) {
    fonts.packages =
      with pkgs;
      with inputs.babel.packages.${system};
      [
        noto-fonts
        noto-fonts-extra
        noto-fonts-emoji
        noto-fonts-cjk-sans
        terminus_font
        jbcustom-nf
        sf-pro
        georgia-fonts
      ];
  };
}
