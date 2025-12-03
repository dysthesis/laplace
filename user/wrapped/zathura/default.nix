# From https://github.com/sioodmy/dotfiles/blob/main/user/wrapped/zathura/default.nix
{
  pkgs,
  lib,
  ...
}: let
  config = pkgs.writeShellScriptBin "zathurarc" (import ./config.nix lib);
in
  pkgs.symlinkJoin {
    name = "zathura-wrapped";
    paths = [pkgs.zathura];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/zathura --add-flags "--config-dir=${config}/bin"
    '';
  }
