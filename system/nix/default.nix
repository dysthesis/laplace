{
  lib,
  config,
  ...
}: let
  inherit (lib.laplace.modules) importInDirectory;
  inherit (lib) optionals;
in {
  config = {
    # The Determinate module selects Nix.
    # Nixd manages evaluator defaults, its substituter and cache key rotation in /etc/nix/nix.conf.
    nix.settings = {
      extra-sandbox-paths = lib.optionals config.programs.ccache.enable [config.programs.ccache.cacheDir];
      experimental-features =
        [
          "nix-command"
          "flakes"
          "pipe-operators"
        ]
        # parallel-eval enables builtins.parallel. Nixd manages eval-cores.
        ++ optionals config.determinate.enable ["parallel-eval"];
      substituters = [
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      auto-optimise-store = true;
    };

    nixpkgs = {
      config = {
        # mkWrapper names derivations "<name>-wrapped" but keeps the unfree meta.license.
        # Match the name without the suffix.
        allowUnfreePredicate = pkg:
          builtins.elem (lib.removeSuffix "-wrapped" (lib.getName pkg)) [
            "rtk"
            "obsidian"
            "graalvm-oracle"
            "minecraft-server"
            "steam"
            "steam-unwrapped"
            "firefox-esr-140-bin-unwrapped"
          ];
        permittedInsecurePackages = [
          "firefox-esr-140-bin-unwrapped-140.17.0esr"
        ];

        rocmSupport = builtins.elem "amd" config.laplace.hardware.gpu;
      };
    };
  };
  imports = importInDirectory ./.;
}
