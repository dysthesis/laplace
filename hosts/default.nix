{
  inputs,
  self,
  lib,
  ...
}: let
  inherit (lib.laplace.system) mkSystem;
  inherit (builtins) mapAttrs;
  hosts = {
    phobos = "x86_64-linux"; # Laptop
    deimos = "x86_64-linux"; # PC
    chaos = "x86_64-linux"; # Installer ISO
    hephaestus = "x86_64-linux"; # Forgejo host on Proxmox
    hermes = "x86_64-linux"; # AdGuard Home
    portunus = "x86_64-linux"; # Reverse proxy host on Proxmox
    bifrost = "x86_64-linux"; # Headscale host on Proxmox
  };
  defaultImports = [
    ../system
    ../modules
    ../user
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.nixosModules.nix-index
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
        nixosProfiles = ["minimal"];
        specialArgs = {inherit lib;};
        config = {
          documentation.man.enable = true;
          programs.nix-index-database.comma.enable = true;
          # Use stable nixpkgs by default, but allow accessing unstable packages
          # by using `pkgs.unstable`
          nixpkgs.overlays = [
            self.overlays.linux-hardened
            # Flake-local font packages (formerly from nixpressions).
            (import ../nix/pkgs)
            (import ../nix/overlays/unstable.nix inputs)
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
