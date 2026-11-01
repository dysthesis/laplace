# Alias destinations include pinned IPv4 and IPv6 addresses. Headscale omits the protocol.
# nftables supplies the protocol-specific restriction.
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
