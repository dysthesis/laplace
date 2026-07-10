pkgs:
pkgs.mkShell {
  name = "Poincare";
  packages = with pkgs; [
    nil
    nixd
    alejandra
    # FIXME: remove on new release of statix
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
    # Push-deploy the Proxmox guests (`just deploy`). simplification: uses the
    # raw `colmena` flake output via nixpkgs' CLI rather than the colmena flake
    # input + makeHive; add the input if hermetic `nix run`/`flake check` eval is
    # wanted.
    colmena

    bash-language-server
    shfmt
    shellcheck
    mergiraf
    defuddle
    nodejs

    packwiz # for modpack management
  ];
}
