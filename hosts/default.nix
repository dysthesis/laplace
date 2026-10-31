{
  inputs,
  self,
  lib,
  cluster,
  ...
}: let
  inherit (builtins) mapAttrs;
  hosts = cluster.manifest.hosts;
  defaultImports = [
    ../system
    ../modules
    ../user
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.nixosModules.nix-index
  ];

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

  # Both evaluators receive the same module list and import-time arguments.
  nodeModules =
    mapAttrs (hostname: host: {
      system = host.system;
      specialArgs = {
        inherit self inputs lib;
        cluster = cluster.manifest;
      };
      modules = [
        inputs.chaotic.nixosModules.nyx-cache
        inputs.chaotic.nixosModules.nyx-overlay
        inputs.chaotic.nixosModules.nyx-registry
        {networking.hostName = hostname;}
        {nixpkgs.hostPlatform = lib.mkDefault host.system;}
        ({modulesPath, ...}: {
          # hardened.nix breaks Wi-Fi; equivalent manual options do not.
          imports = ["${modulesPath}/profiles/minimal.nix"];
        })
        {
          documentation.man.enable = true;
          programs.nix-index-database.comma.enable = true;
          nixpkgs.overlays = overlays;
          imports = [./${hostname} (cluster.hostModule hostname)] ++ defaultImports;
        }
        inputs.determinate.nixosModules.default
      ];
    })
    hosts;
in {
  nixosConfigurations = mapAttrs (_: lib.nixosSystem) nodeModules;
  inherit nodeModules overlays;
}
