{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.laplace.modules) importNixInDirectory;
in {
  imports = importNixInDirectory "default.nix" ./.;

  xdg = {
    enable = true;
    mime.enable = true;
  };

  home.packages = with pkgs; [
    xdg-utils
    xdg-user-dirs
  ];
}
