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
    # TODO: map this to all architectures
    # Installer ISO
    erebus = "x86_64-linux";
    phobos = "x86_64-linux";
    deimos = "x86_64-linux";
  };
  defaultImports = [
    ../system
    ../modules
    ../config
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
      ] ++ defaultImports;
    };
  }
) hosts
