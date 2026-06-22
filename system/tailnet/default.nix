# Single source of truth for the tailnet — the "frontend" the §5 topology audit
# (PLAN.md) describes. This file is the SCHEMA + VALIDATION half: the
# laplace.tailnet option types (the trust-boundary input validation) and
# checkTailnet (referential integrity + the negative security invariants). The
# DATA those options carry — nodes, the role->role reachability matrix, guest
# cohorts — lives in ./policy.nix, kept apart from the mechanism that processes it.
#
# The renderers consume the merged config: ./firewall.nix (per-node nftables) on
# every tailnet host, ./headscale.nix (the ACL) on bifrost. One dataset, no drift;
# imported fleet-wide (via system/ -> importInDirectory) since a node cannot read
# a peer's `config` at eval, and each consumer filters by hostName.
{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption types attrValues concatMap unique elem all;
  inherit (builtins) attrNames head elemAt length match;
  cfg = config.laplace.tailnet;

  # Tags that no untrusted source (a guest cohort, or the game node) may reach.
  # The negative invariants below enforce this; it is the §5 layer-4 check made
  # eval-time.
  sensitiveTags = ["infra" "apps" "monitor" "exit" "workstation"];

  allTags = unique (concatMap (n: n.tags) (attrValues cfg.nodes));
  tagDefined = t: elem t allTags;

  # Port grammar: "*" (all), or "<proto>/<port>" with proto in {tcp,udp} and
  # port an int or "lo-hi" range. The renderers (later) reuse this same grammar;
  # for now it only gates the checker.
  portOk = s:
    s
    == "*"
    || (
      let
        parts = lib.splitString "/" s;
      in
        length parts
        == 2
        && elem (head parts) ["tcp" "udp"]
        && match "[0-9]+(-[0-9]+)?" (elemAt parts 1) != null
    );

  ips = map (n: n.ip) (attrValues cfg.nodes);
  ip6s = map (n: n.ip6) (attrValues cfg.nodes);

  # checkTailnet — referential integrity + the negative security invariants,
  # wired into assertions so a typo or a policy regression fails eval, fleet-wide.
  flowAsserts =
    concatMap (f: [
      {
        assertion = f.from == "*" || tagDefined f.from;
        message = "laplace.tailnet: flow from '${f.from}' is not a defined node tag";
      }
      {
        assertion = tagDefined f.to;
        message = "laplace.tailnet: flow to '${f.to}' is not a defined node tag";
      }
      {
        assertion = all portOk f.ports;
        message = "laplace.tailnet: flow ${f.from}->${f.to} has a malformed port token (want proto/port or *)";
      }
      {
        assertion = !(f.from == "game" && elem f.to sensitiveTags);
        message = "laplace.tailnet INVARIANT violated: game must not reach sensitive tag '${f.to}'";
      }
    ])
    cfg.flows;

  guestAsserts = concatMap (gname: let
    g = cfg.guests.${gname};
  in
    concatMap (rtag: [
      {
        assertion = tagDefined rtag;
        message = "laplace.tailnet: guest '${gname}' reach tag '${rtag}' is not a defined node tag";
      }
      {
        assertion = all portOk g.reach.${rtag};
        message = "laplace.tailnet: guest '${gname}' reach '${rtag}' has a malformed port token";
      }
      {
        assertion = !(elem rtag sensitiveTags);
        message = "laplace.tailnet INVARIANT violated: guest '${gname}' must not reach sensitive tag '${rtag}'";
      }
    ]) (attrNames g.reach)) (attrNames cfg.guests);

  uniqAsserts = [
    {
      assertion = length ips == length (unique ips);
      message = "laplace.tailnet: node IPv4 addresses are not unique";
    }
    {
      assertion = length ip6s == length (unique ip6s);
      message = "laplace.tailnet: node IPv6 addresses are not unique";
    }
  ];
in {
  # policy.nix = the data; firewall.nix + headscale.nix = the enforcement backends
  # (per-node nftables / the headscale ACL). All three consume the schema below.
  imports = [./policy.nix ./firewall.nix ./headscale.nix];

  options.laplace.tailnet = {
    nodes = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          ip = mkOption {
            type = types.str;
            description = "Stable Headscale-assigned tailnet IPv4 (bare address, no prefix).";
          };
          ip6 = mkOption {
            type = types.str;
            description = ''
              Stable tailnet IPv6 ULA (fd7a:115c:a1e0::/48). Pinned per node so the
              coming nftables layer matches v6 by identity, not just tailnet
              membership (PLAN §5a gotcha 1).
            '';
          };
          tags = mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              Role tags (bare, no `tag:` prefix). The reachability matrix and the
              per-node nftables/headscale renderers key off these.
            '';
          };
        };
      });
      default = {};
      description = ''
        Tailnet nodes keyed by hostname. The sole source of truth for tailnet
        addressing and roles. Confirmed against `headscale nodes list`.
      '';
    };

    flows = mkOption {
      type = types.listOf (types.submodule {
        options = {
          from = mkOption {
            type = types.str;
            description = ''Source role tag, or "*" for every node.'';
          };
          to = mkOption {
            type = types.str;
            description = "Destination role tag.";
          };
          ports = mkOption {
            type = types.listOf types.str;
            description = ''Port tokens: "<proto>/<port>" (tcp|udp) or "*".'';
          };
        };
      });
      default = [];
      description = ''
        The reachability matrix (role -> role : ports). Sole source of truth for
        node-to-node tailnet access; drives the headscale ACL and the per-node
        nftables rules. `from = "*"` means every node.
      '';
    };

    guests = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          users = mkOption {
            type = types.listOf types.str;
            description = "Headscale usernames in this cohort.";
          };
          reach = mkOption {
            type = types.attrsOf (types.listOf types.str);
            description = ''
              Destination role tag -> port tokens the cohort may reach. Guest
              device IPs are dynamic, so nftables opens the backend port to the
              whole tailnet and the headscale ACL gates WHO; this is the identity
              half.
            '';
          };
        };
      });
      default = {};
      description = "Guest cohorts (identity-based, Headscale-only).";
    };
  };

  # The data lives in ./policy.nix; this is the validation half — the negative
  # security invariants and referential integrity, read off the merged config.
  config.assertions = flowAsserts ++ guestAsserts ++ uniqAsserts;
}
