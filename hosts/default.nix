{
  inputs,
  self,
  lib,
  ...
}: let
  inherit (lib.laplace.system) mkSystem mkSystemModules;
  inherit (builtins) mapAttrs;
  hosts = {
    phobos = "x86_64-linux"; # Laptop
    deimos = "x86_64-linux"; # PC
    chaos = "x86_64-linux"; # Installer ISO
    hephaestus = "x86_64-linux"; # Forgejo host on Proxmox
    hermes = "x86_64-linux"; # AdGuard Home
    portunus = "x86_64-linux"; # Reverse proxy host on Proxmox
    bifrost = "x86_64-linux"; # Headscale host on Proxmox
    charon = "x86_64-linux"; # Tailscale exit node
    mneme = "x86_64-linux"; # Immich
    mimir = "x86_64-linux"; # Miniflux + SilverBullet
    loki = "x86_64-linux"; # Dedicated Minecraft host on Proxmox
  };
  defaultImports = [
    ../system
    ../modules
    ../user
    inputs.disko.nixosModules.disko
    inputs.nix-index-database.nixosModules.nix-index
  ];
  extraModules = [inputs.determinate.nixosModules.default];

  # Stable nixpkgs by default, with unstable reachable via `pkgs.unstable` plus
  # the flake-local packages. Exposed below so the colmena hive bakes the
  # identical set into its (pre-evaluated) meta.nixpkgs - one source of truth.
  overlays = [
    self.overlays.linux-hardened
    # Flake-local font packages (formerly from nixpressions).
    (import ../nix/pkgs)
    (import ../nix/overlays/unstable.nix inputs)
    inputs.nix-minecraft.overlay
    # Bound switch-to-configuration so a hung activation self-recovers instead
    # of spinning forever on the lock (see the file for the upstream bug).
    (import ../nix/overlays/stc-timeout.nix)
  ];

  # mkSystem-arg builder, shared so `nixosConfigurations` and the `colmena` hive
  # (which needs the raw module list, not a built system) stay one source of truth.
  mkArgs = hostname: system: {
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
      nixpkgs.overlays = overlays;
      imports =
        [
          ./${hostname}
        ]
        ++ defaultImports;
    };
  };
in {
  nixosConfigurations = mapAttrs (hostname: system: mkSystem (mkArgs hostname system)) hosts;
  # Per-host {modules, specialArgs, system} for Colmena to instantiate itself.
  nodeModules = mapAttrs (hostname: system: mkSystemModules (mkArgs hostname system)) hosts;
  inherit overlays;
}
