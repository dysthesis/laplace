inputs: pkgs: let
  headroom = pkgs.callPackage ./headroom.nix {};
  serena = pkgs.callPackage ../../user/wrapped/serena {
    serena = inputs.serena.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
in
  pkgs.mkShell {
    name = "laplace-dev";
    packages = with pkgs; [
      nil
      nixd
      alejandra
      # Temporary Statix compatibility override.
      (statix.overrideAttrs (_o: rec {
        src = fetchFromGitHub {
          owner = "oppiliappan";
          repo = "statix";
          rev = "43681f0da4bf1cc6ecd487ef0a5c6ad72e3397c7";
          hash = "sha256-LXvbkO/H+xscQsyHIo/QbNPw2EKqheuNjphdLfIZUv4=";
        };

        cargoDeps = pkgs.rustPlatform.importCargoLock {
          lockFile = src + "/Cargo.lock";
          allowBuiltinFetchGit = true;
        };
      }))
      deadnix
      just
      npins
      sops
      rsync
      # simplification: uses nixpkgs Colmena; add its flake for hermetic evaluation.
      colmena

      bash-language-server
      shfmt
      shellcheck
      mergiraf

      npins

      defuddle
      nodejs
      headroom
      serena

      packwiz # for modpack management
    ];
  }
