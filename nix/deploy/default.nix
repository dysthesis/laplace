# LAN transport remains independent of application DNS and Tailnet policy.
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
        # Preserve Colmena's name/nodes arguments; share all our import-time args.
        nodeSpecialArgs = lib.mapAttrs (name: _: nodeModules.${name}.specialArgs) hosts;
      };
    }
    // lib.mapAttrs mkNode hosts)
