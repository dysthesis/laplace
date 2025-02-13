{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.babel.modules) importInDirectory;
in
{
  config.nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
      auto-optimise-store = true;
    };
  };
  imports = importInDirectory ./.;
}
