{
  perSystem = {
    inputs',
    pkgs,
    ...
  }: let
    poincare = inputs'.poincare.packages.default;
  in {
    devShells.default = pkgs.mkShell {
      name = "Laplace development shell";
      packages = with pkgs; [
        nil
        alejandra
        statix
        deadnix
        poincare
      ];
    };
  };
}
