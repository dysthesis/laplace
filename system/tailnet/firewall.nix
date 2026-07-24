# Per-node nftables rules from the tailnet flow matrix.
# Servers remove tailscale0 from trusted interfaces, making these rules the input gate.
# Exit forwarding, WireGuard, ICMP, workstations, and off-tailnet hosts stay unchanged.
{
  config,
  lib,
  ...
}: let
  inherit (lib) optionalString filter elem attrValues concatMap unique mkIf mkMerge mkForce concatStringsSep splitString;
  inherit (builtins) head elemAt attrNames;
  cfg = config.laplace.tailnet;
  host = config.networking.hostName;
  self = cfg.nodes.${host} or null;
  iface = config.services.tailscale.interfaceName;

  # Guest IPs are dynamic; Headscale gates identity and nftables gates ports.
  tailnetV4 = "100.64.0.0/10";
  tailnetV6 = "fd7a:115c:a1e0::/48";

  # "tcp/443" -> { proto = "tcp"; port = "443"; }; "*" -> all protocols/ports.
  parsePort = s:
    if s == "*"
    then {
      proto = null;
      port = null;
    }
    else let
      p = splitString "/" s;
    in {
      proto = head p;
      port = elemAt p 1;
    };

  line = fam: saddr: pp:
    "iifname \"${iface}\" ${fam} saddr ${saddr}"
    + optionalString (pp.proto != null) " ${pp.proto} dport ${pp.port}"
    + " accept";

  # Node source addresses, IPv4 and IPv6.
  nodeLines = node: pp: [(line "ip" node.ip pp) (line "ip6" node.ip6 pp)];
  # Whole-tailnet addresses for guest ports.
  tailnetLines = pp: [(line "ip" tailnetV4 pp) (line "ip6" tailnetV6 pp)];

  nodesWithTag = tag: filter (n: elem tag n.tags) (attrValues cfg.nodes);
  srcNodes = from:
    if from == "*"
    then attrValues cfg.nodes
    else nodesWithTag from;

  # Exclude exit flows: they traverse FORWARD, not this host's INPUT.
  # An INPUT rule would expose every Charon port without helping exit traffic.
  flowLines = let
    selfFlows = filter (f: f.to != "exit" && elem f.to self.tags) cfg.flows;
  in
    concatMap (
      f:
        concatMap (
          src:
            if src.ip == self.ip
            then []
            else concatMap (pt: nodeLines src (parsePort pt)) f.ports
        ) (srcNodes f.from)
    )
    selfFlows;

  # Guest cohorts served by this host.
  guestLines = concatMap (
    cname: let
      g = cfg.guests.${cname};
    in
      concatMap (
        rt:
          if elem rt self.tags
          then concatMap (pt: tailnetLines (parsePort pt)) g.reach.${rt}
          else []
      ) (attrNames g.reach)
  ) (attrNames cfg.guests);

  rules = unique (flowLines ++ guestLines);

  # Apply the input gate only to tailnet servers, not clients or off-tailnet hosts.
  isServer = self != null && !(elem "workstation" self.tags);
in {
  config = mkMerge [
    (mkIf (self != null && rules != []) {
      networking.firewall.extraInputRules = concatStringsSep "\n" rules + "\n";
    })
    (mkIf isServer {
      networking.firewall.trustedInterfaces = mkForce ["lo"];
    })
  ];
}
