# Tailnet schema and validation. policy.nix holds data; firewall.nix and
# headscale.nix render host-specific rules from the merged config.
{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption types attrValues concatMap unique elem all any filter;
  inherit (builtins) attrNames head elemAt length match;
  cfg = config.laplace.tailnet;

  # Untrusted roles must not reach these tags.
  sensitiveTags = ["infra" "pve" "media" "monitor" "observability" "notifications" "exit" "workstation" "reader" "owner-device" "sync"];

  allTags = unique (concatMap (n: n.tags) (attrValues cfg.nodes));
  tagDefined = t: elem t allTags;

  # Ports are *, or tcp/udp with one port or an inclusive range.
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

  nodesWithTag = tag: filter (n: elem tag n.tags) (attrValues cfg.nodes);
  flowSourceNodes = from:
    if from == "*"
    then attrValues cfg.nodes
    else nodesWithTag from;
  flowHasGameSource = f: any (n: elem "game" n.tags) (flowSourceNodes f.from);

  # Reject invalid references and unsafe reachability during evaluation.
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
        assertion = !(flowHasGameSource f && elem f.to sensitiveTags);
        message = "laplace.tailnet INVARIANT violated: game must not reach sensitive tag '${f.to}' via flow source '${f.from}'";
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
  # policy.nix feeds nftables and Headscale renderers.
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

  config.assertions = flowAsserts ++ guestAsserts ++ uniqAsserts;
}
