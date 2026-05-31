{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib.babel.modules) importInDirectory;
  inherit (lib) optionalAttrs optionals;
  # Determinate-only settings (eval-cores, lazy-trees, parallel-eval) cause
  # warnings on upstream Nix, so gate them on the Determinate package.
  isDeterminateNix = (config.nix.package.pname or "") == "determinate-nix";
in {
  config = {
    nix = {
      # Ensure we actually use Determinate Nix so the guarded settings take effect.
      package = lib.mkDefault inputs.determinate.inputs.nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
      settings =
        {
          extra-platforms = ["aarch64-linux"];
          experimental-features =
            [
              "nix-command"
              "flakes"
              "pipe-operators"
            ]
            ++ optionals isDeterminateNix ["parallel-eval"];
          substituters = [
            "https://install.determinate.systems"
            "https://nix-community.cachix.org"
          ];

          trusted-public-keys = [
            "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
          auto-optimise-store = true;
        }
        # Determinate-only settings are added here so they are only present when
        # the Determinate fork of Nix is used, avoiding warnings on upstream Nix.
        // optionalAttrs isDeterminateNix {
          # Distributes evaluation work across multiple threads. 0 = all cores.
          eval-cores = 0;
          # Scopes file copying to only what's demanded by the evaluation tree.
          lazy-trees = true;
        };
    };

    nixpkgs = {
      config = {
        allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [
            "obsidian"
            "open-webui"
            "steam"
            "steam-unwrapped"
            "todoist-electron"
          ];

        rocmSupport = builtins.elem "amd" config.laplace.hardware.gpu;
      };
    };
  };
  imports = importInDirectory ./.;
}
