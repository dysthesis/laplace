inputs:
inputs.nixpkgs.lib.extend (_final: _prev: {
  laplace = {
    mkSystem = import ./mkSystem.nix inputs;
    options = import ./options _final;
  };
})
