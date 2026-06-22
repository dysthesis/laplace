# Per-node nftables rules derived from the tailnet flow matrix (system/tailnet).
# The L3 enforcement half of the SSOT — same dataset as the headscale ACL, so the
# two layers cannot drift.
#
# STAGED: while the tailscale module keeps tailscale0 in trustedInterfaces, every
# tailnet packet is already accepted before these rules are consulted, so they are
# redundant and CANNOT lock anyone out. They exist so the ruleset + nft counters
# can be verified on a live host first; a later change drops tailscale0 from
# trustedInterfaces (mkForce) to make default-deny real (the flip).
{
  config,
  lib,
  ...
}: let
  inherit (lib) optionalString filter elem attrValues concatMap unique mkIf concatStringsSep splitString;
  inherit (builtins) head elemAt attrNames;
  cfg = config.laplace.tailnet;
  host = config.networking.hostName;
  self = cfg.nodes.${host} or null;
  iface = config.services.tailscale.interfaceName;

  # Guest backends open to the whole tailnet (guest device IPs are dynamic; the
  # headscale ACL is the identity gate, nftables only the port gate).
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

  # identity-pinned v4 + v6 for a node source
  nodeLines = node: pp: [(line "ip" node.ip pp) (line "ip6" node.ip6 pp)];
  # whole-tailnet v4 + v6 for a guest-served port
  tailnetLines = pp: [(line "ip" tailnetV4 pp) (line "ip6" tailnetV6 pp)];

  nodesWithTag = tag: filter (n: elem tag n.tags) (attrValues cfg.nodes);
  srcNodes = from:
    if from == "*"
    then attrValues cfg.nodes
    else nodesWithTag from;

  # node flows whose destination tag this host carries
  flowLines = let
    selfFlows = filter (f: elem f.to self.tags) cfg.flows;
  in
    concatMap (
      f:
        concatMap (
          src:
          # a node never needs a tailnet rule to reach itself
            if src.ip == self.ip
            then []
            else concatMap (pt: nodeLines src (parsePort pt)) f.ports
        ) (srcNodes f.from)
    )
    selfFlows;

  # guest cohorts whose reach tag this host serves
  guestLines =
    concatMap (
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
in {
  config = mkIf (self != null && rules != []) {
    networking.firewall.extraInputRules = concatStringsSep "\n" rules + "\n";
  };
}
