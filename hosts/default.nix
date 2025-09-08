{
  inputs,
  self,
  lib,
  ...
}:
let
  inherit (lib.babel.system) mkSystem;
  inherit (builtins) mapAttrs;
  hosts = {
    erebus = "aarch64-linux"; # Raspberry Pi
    phobos = "x86_64-linux"; # Laptop
    deimos = "x86_64-linux"; # PC
  };
  defaultImports = [
    ../system
    ../modules
    ../user
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.darwinModules.nix-index
  ];
in
mapAttrs (
  hostname: system:
  mkSystem {
    inherit
      system
      hostname
      self
      inputs
      ;
    # BUG: For some reason, wifi is fucked if I import the hardened.nix profile,
    # but not if I add all of the options myself manually. This is so fucking weird.
    profiles = [ "minimal" ];
    specialArgs = { inherit lib; };
    config = {
      programs.nix-index-database.comma.enable = true;
      # Use stable nixpkgs by default, but allow accessing unstable packages
      # by using `pkgs.unstable`
      nixpkgs.overlays = [
        (final: _prev: {
          unstable = inputs.nixpkgs-unstable.legacyPackages.${final.system};
        })
      ];
      imports = [
        ./${hostname}
      ]
      ++ defaultImports;
    };
  }
) hosts
