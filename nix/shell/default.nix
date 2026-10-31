pkgs:
pkgs.mkShell {
  name = "laplace-dev";
  shellHook = ''
    export NIX_CONFIG="''${NIX_CONFIG:-}
    extra-experimental-features = nix-command flakes pipe-operators"
  '';
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
    colmena

    bash-language-server
    shfmt
    shellcheck
    mergiraf

    fish-lsp
    fish

    packwiz # for modpack management
  ];
}
