{lib, ...}: let
  inherit (lib.laplace.modules) importNixInDirectory;
in {
  programs.yazi = {
    enable = true;

    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
  imports = importNixInDirectory "default.nix" ./.;
}
