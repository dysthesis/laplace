# Colmena hive for the Proxmox guests.
#
# Reuses each host's module list (hosts/default.nix `nodeModules`) so there is
# one source of truth; Colmena owns the nixosSystem call to inject its
# `deployment` namespace.
#
# Deploy with `colmena apply --on @proxmox` (or `just deploy`). Targets are LAN
# IPs, NOT tailnet MagicDNS names, by design: a switch that disrupts
# tailscale/DNS on a proxy or headscale guest must not be able to sever the very
# path you are deploying over. Deploy reach-critical guests (bifrost, portunus,
# horos, hermes) one at a time and keep the Proxmox noVNC console open.
#
# Connects as root over SSH (key-only, restricted to the infra VLANs in
# system/profiles/proxmox), so the closure is received and switch-to-configuration
# runs without interactive escalation - doas stays password-prompting for humans.
#
# hephaestus is intentionally absent: not yet deployed, no static IP assigned.
{
  self,
  inputs,
  lib,
  nodeModules,
  # Shared overlay list from hosts/default.nix, baked into meta.nixpkgs so the
  # deployed pkgs match `nixosConfigurations` exactly.
  overlays,
}: let
  inherit (lib) mapAttrs;

  # name -> LAN IP. Add/move a guest by editing this table.
  targets = {
    mneme = "10.0.20.81";
    hermes = "10.0.20.82";
    mimir = "10.0.20.83";
    garmr = "10.0.20.84";
    horos = "10.0.20.85";
    charon = "10.0.20.10";
    portunus = "10.0.40.2";
    bifrost = "10.0.40.3";
  };

  mkNode = name: targetHost: {
    imports = nodeModules.${name}.modules;
    deployment = {
      inherit targetHost;
      targetUser = "root";
      # Build on the workstation and copy the closure; the guests are 1-2 GiB
      # tmpfs-root VMs that would thrash building their own system.
      buildOnTarget = false;
      tags = ["proxmox"];
    };
  };
in
  {
    meta = {
      # Recent Colmena (flakes) requires a pre-evaluated pkgs set here, so bake in
      # the same overlays nixosConfigurations get (passed from hosts/default.nix).
      nixpkgs = import inputs.nixpkgs.outPath {
        system = "x86_64-linux";
        inherit overlays;
      };
      # The host modules read `self`, `inputs`, and the extended `lib` (laplace.*)
      # as specialArgs, exactly as mkSystem passes them.
      specialArgs = {inherit self inputs lib;};
    };
  }
  // mapAttrs mkNode targets
