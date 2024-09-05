{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.laplace.modules) importInDirectory;
in {
  config.nix = {
    package = pkgs.nixFlakes;
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
    };
  };
  imports = importInDirectory ./.;
}
