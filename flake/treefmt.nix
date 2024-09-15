{
  lib,
  inputs,
  ...
}: let
  inherit (lib) fold;
in {
  imports = [
    inputs.treefmt.flakeModule
  ];
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs =
        fold (curr: acc:
          acc
          // {
            ${curr}.enable = true;
          })
        {}
        [
          "alejandra"
          "statix"
          "deadnix"
          "prettier"
        ];
    };
  };
}
