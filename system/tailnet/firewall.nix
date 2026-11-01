# Headscale authorises guests. INPUT rules restrict dynamic guest addresses and ports.
# Exit grants use FORWARD traffic, never wildcard INPUT rules.
{
  config,
  lib,
  cluster,
  ...
}: let
  inherit (lib) concatMap concatStringsSep filter mkIf mkMerge mkForce unique optionalString;
  hostName = config.networking.hostName;
  host = cluster.hosts.${hostName};
  iface = config.services.tailscale.interfaceName;
  self = host.tailnet;
  line = family: source: token: let
    parts = lib.splitString "/" token;
  in
    "iifname \"${iface}\" ${family} saddr ${source}"
    + optionalString (token != "*") " ${builtins.head parts} dport ${builtins.elemAt parts 1}"
    + " accept";
  nodeLines = source: token: [(line "ip" source.ip token) (line "ip6" source.ip6 token)];
  connections = filter (c: !c.forwarding && builtins.elem hostName c.destinationNodes) cluster.network.connections;
  rules =
    if self == null
    then []
    else
      unique (concatMap (
          c:
            if c.guest != null
            then
              concatMap (token: [
                (line "ip" "100.64.0.0/10" token)
                (line "ip6" "fd7a:115c:a1e0::/48" token)
              ])
              c.ports
            else
              concatMap (name: concatMap (nodeLines cluster.nodes.${name}) c.ports)
              (filter (name: name != hostName) c.sourceNodes)
        )
        connections);
in {
  config = mkMerge [
    (mkIf (rules != []) {networking.firewall.extraInputRules = concatStringsSep "\n" rules + "\n";})
    (mkIf (host.role == "server" && self != null) {networking.firewall.trustedInterfaces = mkForce ["lo"];})
  ];
}
