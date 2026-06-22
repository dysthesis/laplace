# Headscale ACL derived from the tailnet flow matrix (system/tailnet). The
# identity-layer backend of the SSOT: the same flows/guests that render per-node
# nftables (firewall.nix) render the headscale policy here, so the two layers
# enforce ONE matrix and cannot drift.
#
# Only the headscale host evaluates the config (guarded on
# laplace.services.headscale.enable); every other host imports this for free and
# the guard makes it inert.
#
# Tag-based. Every node is tagged with its role tag at enrolment (a runtime step,
# like guest onboarding). Assigning a tag STRIPS a node's Headscale user, so
# group:admin is now purely the tag OWNER, not a mesh — the old full mesh is
# decomposed into the explicit `flows`. Guests stay identity-based (groups), as
# their device IPs are dynamic.
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf concatMap unique attrValues genAttrs mapAttrs elemAt splitString;
  cfg = config.laplace.tailnet;

  # Every role tag carried by any node. Used both as the `*`-source expansion and
  # as the tagOwners key set (headscale requires an owner for every tag named in
  # the policy).
  allTags = unique (concatMap (n: n.tags) (attrValues cfg.nodes));
  tagRef = t: "tag:${t}";

  # "tcp/443" -> "443"; "udp/53" -> "53"; "*" stays "*". A headscale dst token
  # carries no protocol (port only), so tcp/udp of the same port collapse to one.
  portOf = s:
    if s == "*"
    then "*"
    else elemAt (splitString "/" s) 1;
  portTokens = ports: unique (map portOf ports);

  # A flow -> one accept rule. `from = "*"` is every node TAG (not a literal `*`,
  # which would also match guest devices and breach the guests-never-reach-
  # sensitive-tags invariant); the L3 layer pins the same node set. `to = "exit"`
  # is internet egress through the exit node -> autogroup:internet:*, not reaching
  # the charon device's own ports.
  flowRule = f: {
    src =
      if f.from == "*"
      then map tagRef allTags
      else [(tagRef f.from)];
    dst =
      if f.to == "exit"
      then ["autogroup:internet:*"]
      else map (p: "${tagRef f.to}:${p}") (portTokens f.ports);
  };

  # Guest cohort reach -> "tag:<to>:<port>" destination tokens.
  guestDestinations = g:
    concatMap (
      rt: map (p: "${tagRef rt}:${p}") (portTokens g.reach.${rt})
    ) (builtins.attrNames g.reach);
in {
  config = mkIf config.laplace.services.headscale.enable {
    laplace.services.headscale.acl = {
      # The account that owns the nodes owns every role tag. group:admin is
      # defined below (members only, no destinations) purely to be this owner.
      tagOwners = genAttrs (map tagRef allTags) (_: ["group:admin"]);

      rules = map flowRule cfg.flows;

      groups =
        {
          # Owner identity only: every node is tagged, so admin meshes nothing;
          # the mesh is the explicit flows above. Empty destinations -> acl.nix
          # emits no accept rule for it (it stays only the tag owner).
          admin = {
            members = ["demiurge"];
            destinations = [];
          };
        }
        // mapAttrs (_: g: {
          members = g.users;
          destinations = guestDestinations g;
        })
        cfg.guests;

      # F5: only charon (tag:exit) may self-approve the 0.0.0.0/0 + ::/0 routes,
      # not any admin-owned node.
      autoApprovers.exitNode = ["tag:exit"];
    };
  };
}
