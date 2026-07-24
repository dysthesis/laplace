# Headscale ACL from the same flows used by the nftables renderer.
# Role tags replace user identity on nodes; guest cohorts remain identity groups.
# Only the Headscale host activates this module.
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf concatMap unique attrValues genAttrs mapAttrs elemAt splitString;
  cfg = config.laplace.tailnet;

  # Role tags expand * sources and define required tag owners.
  allTags = unique (concatMap (n: n.tags) (attrValues cfg.nodes));
  tagRef = t: "tag:${t}";

  # Headscale destinations omit protocol, so equal TCP and UDP ports collapse.
  portOf = s:
    if s == "*"
    then "*"
    else elemAt (splitString "/" s) 1;
  portTokens = ports: unique (map portOf ports);

  # Expand * to node tags, not guests. Exit flows target autogroup:internet.
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
      # group:admin owns role tags but receives no reachability rule.
      tagOwners = genAttrs (map tagRef allTags) (_: ["group:admin"]);

      rules = map flowRule cfg.flows;

      groups =
        {
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

      # Only tag:exit may approve default routes.
      autoApprovers.exitNode = ["tag:exit"];
    };
  };
}
