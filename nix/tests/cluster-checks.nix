{
  pkgs,
  lib,
  inputs,
  self,
  cluster,
  nixosConfigurations,
}: {
  cluster-contracts = let
    contracts = import ./cluster.nix {inherit lib;};
  in
    builtins.deepSeq cluster.manifest (builtins.deepSeq contracts
      (pkgs.writeText "cluster-contracts.json" (builtins.toJSON contracts)));

  cluster-global-validation = let
    contracts = import ./cluster-evaluators.nix {inherit lib inputs self;};
  in
    builtins.deepSeq contracts (pkgs.writeText "cluster-evaluators.json" (builtins.toJSON contracts));

  cluster-personal-services = let
    checks =
      (import ./personal-services.nix {
        inherit pkgs;
        sopsModule = inputs.sops-nix.nixosModules.sops;
      }).checks;
  in
    builtins.deepSeq checks (pkgs.writeText "personal-service-contracts.json" (builtins.toJSON checks));

  cluster-lifecycle = import ./cluster-lifecycle.nix {
    inherit pkgs;
    sopsModule = inputs.sops-nix.nixosModules.sops;
  };

  cluster-adguard-caddy = import ./adguard-caddy.nix {
    inherit pkgs;
    sopsModule = inputs.sops-nix.nixosModules.sops;
  };

  endpoint-dials = let
    contracts = import ./endpoint-dials.nix {inherit lib;};
  in
    builtins.deepSeq contracts (pkgs.writeText "endpoint-dials.json" (builtins.toJSON contracts));

  cluster-evaluator-parity = let
    selected = config: {
      applications = lib.mapAttrs (_: value: value.enable or null) config.laplace.services;
      inherit (config.services.caddy) virtualHosts;
      containers = builtins.attrNames config.virtualisation.oci-containers.containers;
      nodes = config.laplace.tailnet.nodes;
    };
    checks =
      lib.mapAttrs (
        name: node:
          assert lib.all (a: a.assertion) node.config.assertions;
          assert lib.all (a: a.assertion) nixosConfigurations.${name}.config.assertions;
            selected node.config == selected nixosConfigurations.${name}.config
      )
      self.colmenaHive.nodes;
  in
    assert lib.all (value: value) (builtins.attrValues checks);
      pkgs.writeText "cluster-evaluator-parity.json" (builtins.toJSON checks);
}
