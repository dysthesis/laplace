{inputs, ...}: {
  imports = [
    inputs.treefmt.flakeModule
  ];
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs = {
        alejandra.enable = true;
        deadnix.enable = true;
        prettier.enable = true;
      };
    };
  };
}
