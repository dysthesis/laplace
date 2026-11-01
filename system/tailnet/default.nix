# Render only the validated cluster model. Bind live tags to individual nodes.
{
  lib,
  cluster,
  ...
}: {
  imports = [./firewall.nix ./headscale.nix];
  options.laplace.tailnet.nodes = lib.mkOption {
    readOnly = true;
    default = cluster.nodes;
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        ip = lib.mkOption {type = lib.types.str;};
        ip6 = lib.mkOption {type = lib.types.str;};
        tags = lib.mkOption {type = lib.types.listOf lib.types.str;};
      };
    });
    description = "Checked union of managed Tailnet identities and unmanaged peers.";
  };
}
