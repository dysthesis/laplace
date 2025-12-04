{
  inputs,
  self,
  lib,
  ...
}: let
  inherit (lib.babel.system) mkSystem;
  inherit (builtins) mapAttrs;
  hosts = {
    erebus = "aarch64-linux"; # Raspberry Pi
    phobos = "x86_64-linux"; # Laptop
    deimos = "x86_64-linux"; # PC
    chaos = "x86_64-linux"; # Installer ISO
  };
  defaultImports = [
    ../system
    ../modules
    ../user
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.darwinModules.nix-index
  ];
  extraModules = [inputs.determinate.nixosModules.default];
in
  mapAttrs (
    hostname: system:
      mkSystem {
        inherit
          system
          hostname
          self
          inputs
          extraModules
          ;
        # BUG: For some reason, wifi is fucked if I import the hardened.nix profile,
        # but not if I add all of the options myself manually. This is so fucking weird.
        profiles = ["minimal"];
        specialArgs = {inherit lib;};
        config = {
          documentation.man.enable = true;
          programs.nix-index-database.comma.enable = true;
          # Use stable nixpkgs by default, but allow accessing unstable packages
          # by using `pkgs.unstable`
          nixpkgs.overlays = [
            (final: _prev: {
              unstable = inputs.nixpkgs-unstable.legacyPackages.${final.system};
            })
          ];
          imports =
            [
              ./${hostname}
            ]
            ++ defaultImports;
        };
      }
  )
  hosts
