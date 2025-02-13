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
    inputs.disko.nixosModules.disko
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
    specialArgs = { inherit lib; };
    config = {
      imports = [
        ./${hostname}
      ] ++ defaultImports;
    };
  }
) hosts
