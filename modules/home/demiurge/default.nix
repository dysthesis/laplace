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
    username = "demiurge";
    homeDirectory = "/home/${username}";
    stateVersion = "24.05";
    sessionVariables = {
      BROWSER = "${getExe pkgs.firefox}";
      EDITOR = "${getExe inputs.poincare.packages.${pkgs.system}.default}";
    };
  };

  imports = importInDirectory ./.;
}