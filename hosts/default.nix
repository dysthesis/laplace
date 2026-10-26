{
  inputs,
  self,
  lib,
  cluster,
  ...
}: let
  inherit (lib.laplace.system) mkSystem mkSystemModules;
  inherit (builtins) mapAttrs;
  hosts = cluster.manifest.hosts;
  defaultImports = [
    ../system
    ../modules
    ../user
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.nixosModules.nix-index
  ];
  extraModules = [inputs.determinate.nixosModules.default];

  # Colmena and nixosConfigurations share this package set.
  overlays = [
    self.overlays.linux-hardened
    (import ../nix/pkgs)
    (import ../nix/overlays/unstable.nix inputs)
    (import ../nix/overlays/nix-output-monitor.nix)
    inputs.nix-minecraft.overlay
    # Bound hung activations so they release the deployment lock.
    (import ../nix/overlays/stc-timeout.nix)
  ];

  # Shared inputs for nixosConfigurations and Colmena.
  mkArgs = hostname: host: {
    system = host.system;
    inherit
      hostname
      self
      inputs
      extraModules
      ;
    # hardened.nix breaks Wi-Fi; equivalent manual options do not.
    nixosProfiles = ["minimal"];
    specialArgs = {
      inherit lib;
      cluster = cluster.manifest;
    };
    config = {
      documentation.man.enable = true;
      programs.nix-index-database.comma.enable = true;
      nixpkgs.overlays = overlays;
      imports =
        [
          ./${hostname}
          (cluster.hostModule hostname)
        ]
        ++ defaultImports;
    };
  };
in {
  nixosConfigurations = mapAttrs (hostname: host: mkSystem (mkArgs hostname host)) hosts;
  # Per-host {modules, specialArgs, system} for Colmena to instantiate itself.
  nodeModules = mapAttrs (hostname: host: mkSystemModules (mkArgs hostname host)) hosts;
  inherit overlays;
}
