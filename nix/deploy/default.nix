# LAN deployment does not use application DNS or tailnet policy.
{
  inputs,
  lib,
  nodeModules,
  cluster,
  ...
}: let
  hosts = lib.filterAttrs (_: h: h.deployment != null) cluster.hosts;
  packageSet = host: import inputs.nixpkgs.outPath {system = host.system;};
  mkNode = name: host: {
    imports = nodeModules.${name}.modules;
    deployment = host.deployment // {tags = [host.role];};
  };
in
  builtins.deepSeq cluster ({
      meta = {
        nixpkgs = import inputs.nixpkgs.outPath {system = "x86_64-linux";};
        nodeNixpkgs = lib.mapAttrs (_: packageSet) hosts;
        # Keep Colmena's name and nodes arguments separate from module arguments.
        nodeSpecialArgs = lib.mapAttrs (name: _: nodeModules.${name}.specialArgs) hosts;
      };
    }
    // lib.mapAttrs mkNode hosts)
