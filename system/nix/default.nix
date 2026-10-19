{
  lib,
  config,
  ...
}: let
  inherit (lib.laplace.modules) importInDirectory;
  inherit (lib) optionals;
in {
  config = {
    # The Determinate module selects Nix; Nixd manages evaluator defaults,
    # its substituter, and rotating cache keys in /etc/nix/nix.conf.
    nix.settings = {
      experimental-features =
        [
          "nix-command"
          "flakes"
          "pipe-operators"
        ]
        # Enables builtins.parallel; eval-cores is managed by Nixd.
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
        # mkWrapper renames derivations to "<name>-wrapped" but keeps the
        # unfree meta.license, so match on the unwrapped name.
        allowUnfreePredicate = pkg:
          builtins.elem (lib.removeSuffix "-wrapped" (lib.getName pkg)) [
            "obsidian"
            "graalvm-oracle"
            "minecraft-server"
            "steam"
            "steam-unwrapped"
            "firefox-esr-140-bin-unwrapped"
          ];

        rocmSupport = builtins.elem "amd" config.laplace.hardware.gpu;
      };
    };
  };
  imports = importInDirectory ./.;
}
