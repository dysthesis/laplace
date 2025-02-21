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
  ];
in
mapAttrs (
  hostname: system:
  let
    defaultProfiles = [ "hardened" ];
    profiles = if hostname == "erebus" then defaultProfiles else defaultProfiles ++ [ "minimal" ];
  in
  mkSystem {
    inherit
      system
      hostname
      self
      inputs
      profiles
      ;
    specialArgs = { inherit lib; };
    config = {
      # profiles.hardened = true;
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
