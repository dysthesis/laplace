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
    argus = "x86_64-linux"; # Observability host on Proxmox
    horos = "x86_64-linux"; # Uptime Kuma + ntfy host on Proxmox
    hephaestus = "x86_64-linux"; # Forgejo host on Proxmox
    talos = "x86_64-linux"; # Forgejo Actions runner on Proxmox
    hermes = "x86_64-linux"; # AdGuard Home
    portunus = "x86_64-linux"; # Reverse proxy host on Proxmox
    bifrost = "x86_64-linux"; # Headscale host on Proxmox
    charon = "x86_64-linux"; # Tailscale exit node
    mneme = "x86_64-linux"; # Immich
    mimir = "x86_64-linux"; # Application services + Syncthing
    apollo = "x86_64-linux"; # Music automation and streaming host on Proxmox
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

  # Colmena and nixosConfigurations share this package set.
  overlays = [
    self.overlays.linux-hardened
    (import ../nix/pkgs)
    (import ../nix/overlays/unstable.nix inputs)
    inputs.nix-minecraft.overlay
    # Bound hung activations so they release the deployment lock.
    (import ../nix/overlays/stc-timeout.nix)
  ];

  # Shared inputs for nixosConfigurations and Colmena.
  mkArgs = hostname: system: {
    inherit
      system
      hostname
      self
      inputs
      extraModules
      ;
    # hardened.nix breaks Wi-Fi; equivalent manual options do not.
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
