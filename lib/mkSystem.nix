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
        ]
        ++ config;
      specialArgs = {inherit self inputs;} // specialArgs;
    }
