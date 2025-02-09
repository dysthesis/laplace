{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.laplace.modules) importInDirectory;
in {
  config.nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      experimental-features = ["nix-command" "flakes" "pipe-operators"];
      auto-optimise-store = true;
    };
  };
  imports = importInDirectory ./.;
}
