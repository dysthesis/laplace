{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.babel.modules) importInDirectory;
in {
  config = {
    nix = {
      package = pkgs.nixVersions.stable;
      settings = {
        extra-platforms = ["aarch64-linux"];
        experimental-features = [
          "nix-command"
          "flakes"
          "pipe-operators"
        ];
        substituters = [
          "https://nix-community.cachix.org"
        ];

        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
        auto-optimise-store = true;
      };
    };

    nixpkgs = {
      config = {
        allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [
            "open-webui"
            "steam"
            "steam-unwrapped"
          ];
        # allowBroken = true;
        rocmSupport = true;
      };
    };
  };
  imports = importInDirectory ./.;
}
