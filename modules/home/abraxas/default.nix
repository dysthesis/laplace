{
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) getExe;
  inherit (lib.laplace.modules) importInDirectory;
in {
  # Let home-manager manage itself
  programs.home-manager.enable = true;

  home = rec {
    username = "abraxas";
    homeDirectory = "/home/${username}";
    stateVersion = "24.05";
    sessionVariables = {
      EDITOR = "${getExe inputs.poincare.packages.${pkgs.system}.default}";
    };
    packages = with pkgs; [
      inputs.poincare.packages.${pkgs.system}.default
      comma
      wezterm
    ];
  };

  imports = importInDirectory ./.;
}
