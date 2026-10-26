# Alias destinations explicitly include both pinned address families. Headscale
# still omits protocol; nftables supplies the protocol-specific second gate.
{
  config,
  lib,
  cluster,
  ...
}: {
  config = lib.mkIf config.laplace.services.headscale.enable {
    laplace.services.headscale.acl = {
      inherit (cluster.network) rules groups tagOwners;
      hosts = cluster.network.aliases;
      autoApprovers.exitNode = ["tag:exit"];
    };
  };
}
