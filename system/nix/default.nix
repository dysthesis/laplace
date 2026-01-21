{
  inputs,
  lib,
  config,
  ...
}: let
  inherit (lib.babel.modules) importInDirectory;
in {
  config = {
    nix = {
      settings = {
        extra-platforms = ["aarch64-linux"];
        experimental-features = [
          "nix-command"
          "flakes"
          "pipe-operators"
        ];
        substituters = [
          "https://install.determinate.systems"
          "https://nix-community.cachix.org"
        ];

        trusted-public-keys = [
          "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
        auto-optimise-store = true;

        # NOTE: These options are only available with Determinate Nix.
        # Distributes evaluation work across multiple threads. 0 means "use as
        # many cores as there are available".
        # See:
        # https://docs.determinate.systems/determinate-nix/#parallel-evaluation
        eval-cores = 0;
        # Scopes file copying to what the specific expression demands.
        # See:
        # https://docs.determinate.systems/determinate-nix/#lazy-trees
        lazy-trees = true;
      };
    };

    nixpkgs = {
      config = {
        allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [
            "open-webui"
            "steam"
            "steam-unwrapped"
            "obsidian"
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
