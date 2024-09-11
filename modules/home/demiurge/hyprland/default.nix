{
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.laplace.modules) importNixInDirectory importInDirectory;
in {
  wayland.windowManager.hyprland = {
    enable = true;
  };

  imports = importNixInDirectory "default.nix" ./. ++ importInDirectory ./.;
}
