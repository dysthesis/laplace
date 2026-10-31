{
  pkgs,
  lib,
  inputs,
  self,
  cluster,
  nixosConfigurations,
}: let
  serviceFixtures = import ./service-fixtures.nix {inherit lib inputs self;};
in
  (import ./cluster-checks.nix {inherit pkgs lib inputs self cluster nixosConfigurations;})
  // (import ./desktop-checks.nix {inherit pkgs lib nixosConfigurations;})
  // (import ./minecraft-checks.nix {inherit pkgs lib inputs serviceFixtures;})
  // (import ./headscale-checks.nix {inherit pkgs lib inputs self serviceFixtures;})
  // (import ./telemetry-checks.nix {inherit pkgs lib nixosConfigurations;})
  // (import ./observability-checks.nix {inherit pkgs lib inputs self serviceFixtures;})
  // {
    artifact-cleanup = import ./artifact-cleanup.nix {inherit pkgs;};
    forgejo-runner-address = import ./forgejo-runner-address.nix {inherit pkgs;};
    music-domain = import ./music-domain.nix {inherit pkgs;};
    telemetry-ca-rotation-plan = import ./telemetry-ca-rotation-plan.nix {inherit lib pkgs;};
  }
