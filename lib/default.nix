inputs:
inputs.nixpkgs.lib.extend (final: prev: {
  laplace = {
    mkSystem = import ./mkSystem.nix inputs;
  };
})
