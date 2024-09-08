inputs: let
  inherit (inputs.nixpkgs.lib) nixosSystem mkDefault;
in
  {
    self,
    system,
    hostname,
    config,
    specialArgs,
    ...
  }:
    nixosSystem {
      inherit system;
      modules =
        [
          {
            networking.hostName = hostname;
            nixpkgs.hostPlatform = mkDefault system;
          }
          inputs.disko.nixosModules.disko

          # TODO: Find a better place to put this
          inputs.nix-index-database.nixosModules.nix-index
        ]
        ++ config;
      specialArgs = {inherit self inputs;} // specialArgs;
    }
