inputs: let
  inherit (inputs.nixpkgs.lib) nixosSystem;
in
  {
    system,
    hostname,
    config,
    ...
  }:
    nixosSystem {
      inherit system;
      modules =
        [
          {networking.hostName = hostname;}
        ]
        ++ config;
      specialArgs = {inherit inputs;};
    }
