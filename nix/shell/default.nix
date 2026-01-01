pkgs:
pkgs.mkShell {
  name = "Poincare";
  packages = with pkgs; [
    nixd
    alejandra
    statix
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
