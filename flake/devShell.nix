{
  perSystem = {pkgs, ...}: {
    devShells.default = pkgs.mkShell {
      name = "Laplace development shell";
      packages = with pkgs; [
        nil
        alejandra
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
