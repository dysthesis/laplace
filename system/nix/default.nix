{
  lib,
  config,
  ...
}: let
  inherit (lib.laplace.modules) importInDirectory;
  inherit (lib) optionals;
in {
  config = {
    # Nixd manages evaluator defaults, its substituter and cache key rotation in /etc/nix/nix.conf.
    nix.settings = {
      extra-sandbox-paths = lib.optionals config.programs.ccache.enable [config.programs.ccache.cacheDir];
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

    nixpkgs = {
      config = {
        # mkWrapper adds "-wrapped" to derivation names but keeps the unfree meta.license.
        allowUnfreePredicate = pkg:
          builtins.elem (lib.removeSuffix "-wrapped" (lib.getName pkg)) [
            "rtk"
            "obsidian"
            "graalvm-oracle"
            "minecraft-server"
            "steam"
            "steam-unwrapped"
            "firefox-esr-140-bin-unwrapped"
            "neoforge"
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
