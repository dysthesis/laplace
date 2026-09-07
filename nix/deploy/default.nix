# Colmena reuses each host's modules and package overlays.
# Deploy by LAN IP so tailnet or DNS changes cannot cut the deployment path.
# Root SSH is key-only and VLAN-scoped; deploy critical guests one at a time.
{
  self,
  inputs,
  lib,
  nodeModules,
}: let
  inherit (lib) mapAttrs;

  # name -> LAN IP. Add/move a guest by editing this table.
  targets = {
    argus = "10.0.20.84";
    horos = "10.0.20.85";
    apollo = "10.0.20.86";
    mneme = "10.0.20.81";
    hermes = "10.0.20.82";
    mimir = "10.0.20.83";
    charon = "10.0.20.10";
    portunus = "10.0.40.2";
    bifrost = "10.0.50.2";
    loki = "10.0.60.2";
    hephaestus = "10.0.70.2";
    talos = "10.0.80.2";
  };

  mkNode = name: targetHost: {
    imports = nodeModules.${name}.modules;
    deployment = {
      inherit targetHost;
      targetUser = "root";
      # Build locally; small tmpfs-root guests would thrash.
      buildOnTarget = false;
      tags = ["proxmox"];
    };
  };
in
  {
    meta = {
      nixpkgs = import inputs.nixpkgs.outPath {
        system = "x86_64-linux";
      };
      # Match mkSystem specialArgs.
      specialArgs = {inherit self inputs lib;};
    };
  }
  // mapAttrs mkNode targets
