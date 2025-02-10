{
  self,
  lib,
  inputs,
  ...
}: let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (lib.laplace) mkSystem;
  inherit (builtins) mapAttrs;
  inherit
    (pkgs)
    linuxPackagesFor
    linuxKernel
    ;

  # Map each host to its architecture
  hosts = {
    "yaldabaoth" = "x86_64-linux";
    "astaphaios" = "x86_64-linux";
    "adonaios" = "x86_64-linux";
  };
in {
  flake.nixosConfigurations =
    mapAttrs (hostname: system:
      mkSystem {
        inherit system hostname self;
        specialArgs = {inherit lib;};
        config = [
          ./${hostname}
          "${self}/modules/system"
          "${self}/modules/secrets"
        ];
      })
    hosts
    // {
      iso = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({
            modulesPath,
            ...
          }: {
            imports = let
              cd-drv = "installation-cd-graphical-calamares-plasma6";
            in ["${modulesPath}/installer/cd-dvd/${cd-drv}.nix"];

            # Use the latest kernel packages!
            boot.kernelPackages = linuxPackagesFor linuxKernel.kernels.linux_hardened;
          })
        ];
      };
    };
}
