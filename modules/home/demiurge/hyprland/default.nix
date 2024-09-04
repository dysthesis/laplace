{lib, ...}: let
  inherit (lib.laplace.modules) importNixInDirectory;
in {
  wayland.windowManager.hyprland.enable = true;

  imports = importNixInDirectory "default.nix" ./.;
}
