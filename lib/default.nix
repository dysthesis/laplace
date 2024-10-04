inputs:
inputs.nixpkgs.lib.extend (_final: _prev: {
  laplace = {
    mkSystem = import ./mkSystem.nix inputs;
    mkSubdomain = import ./mkSubdomain.nix;
    options = import ./options _final;
    modules = import ./modules _final;
  };
})
