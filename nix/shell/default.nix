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
    alejandra
    just
    npins
    sops
    rsync

    bash-language-server
    shfmt
    shellcheck
    mergiraf
  ];
}
