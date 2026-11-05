{
  inputs,
  self,
  lib,
  cluster,
  ...
}: let
  inherit (builtins) mapAttrs;
  hosts = cluster.manifest.hosts;
  desktopSelections = import ./desktops.nix;
  defaultImports = [
    ../system
    ../modules
    ../user
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.nixosModules.nix-index
  ];

  # Colmena and nixosConfigurations use the same package set.
  overlays = [
    self.overlays.linux-hardened
    (import ../nix/pkgs)
    (import ../nix/overlays/unstable.nix inputs)
    (import ../nix/overlays/nix-output-monitor.nix)
    inputs.nix-minecraft.overlay
    (import ../nix/overlays/stc-timeout.nix)
  ];

  # Colmena and nixosConfigurations use the same modules and arguments.
  nodeModules =
    mapAttrs (hostname: host: {
      system = host.system;
      specialArgs = {
        inherit self inputs lib;
        cluster = cluster.manifest;
        desktopSelection = (import ../system/display/presets.nix).none // (desktopSelections.${hostname} or {});
      };
      modules = [
        inputs.chaotic.nixosModules.nyx-cache
        inputs.chaotic.nixosModules.nyx-overlay
        inputs.chaotic.nixosModules.nyx-registry
        {networking.hostName = hostname;}
        {nixpkgs.hostPlatform = lib.mkDefault host.system;}
        ({modulesPath, ...}: {
          # The hardened.nix profile causes Wi-Fi failures.
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
