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
      package = lib.mkDefault inputs.determinate.inputs.nix.packages.${pkgs.stdenv.system}.default;
      settings = {
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
          ];
        rocmSupport = true;
      };
      overlays = [
        inputs.emacs.overlays.default
        (_self: super: {
          ccacheWrapper = super.ccacheWrapper.override {
            extraConfig = ''
              export CCACHE_COMPRESS=1
              export CCACHE_DIR="${config.programs.ccache.cacheDir}"
              export CCACHE_UMASK=007
              if [ ! -d "$CCACHE_DIR" ]; then
                echo "====="
                echo "Directory '$CCACHE_DIR' does not exist"
                echo "Please create it with:"
                echo "  sudo mkdir -m0770 '$CCACHE_DIR'"
                echo "  sudo chown root:nixbld '$CCACHE_DIR'"
                echo "====="
                exit 1
              fi
              if [ ! -w "$CCACHE_DIR" ]; then
                echo "====="
                echo "Directory '$CCACHE_DIR' is not accessible for user $(whoami)"
                echo "Please verify its access permissions"
                echo "====="
                exit 1
              fi
            '';
          };
        })
      ];
    };
  };
  imports = importInDirectory ./.;
}
