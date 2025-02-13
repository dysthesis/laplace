{
  perSystem = {pkgs, ...}: {
    devShells.default = pkgs.mkShell {
      name = "Laplace development shell";
      packages = with pkgs; [
        nixd
        nixfmt
        statix
        deadnix
        nvfetcher
        just

        # Sops-Nix and password generation
        sops
        mkpasswd
      ];
    };
  };
}
