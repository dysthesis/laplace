# Single source of truth for the tailnet — the "frontend" the §5 topology audit
# (PLAN.md) describes. It carries node identity (addresses + role tags), the
# role->role reachability matrix, and the guest cohorts. Consumers render the
# enforcement layers from it: the headscale ACL on bifrost today, per-node
# nftables + fail2ban later. One dataset, no drift.
#
# Pure data, identical on every host: a node cannot read a peer's `config` at
# eval, so this is NOT derived from cross-node config — it is a plain constant
# imported fleet-wide (via system/ -> importInDirectory), and each consumer
# filters by `config.networking.hostName`.
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
    s == "*"
    || (
      let parts = lib.splitString "/" s;
      in
        length parts == 2
        && elem (head parts) ["tcp" "udp"]
        && match "[0-9]+(-[0-9]+)?" (elemAt parts 1) != null
    );

  ips = map (n: n.ip) (attrValues cfg.nodes);
  ip6s = map (n: n.ip6) (attrValues cfg.nodes);

  # checkTailnet — referential integrity + the negative security invariants,
  # wired into assertions so a typo or a policy regression fails eval, fleet-wide.
  flowAsserts = concatMap (f: [
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
  ]) cfg.flows;

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
  # The L3 renderer consumes this same data; kept in a separate file so the SSOT
  # data and its enforcement backend stay distinct.
  imports = [./firewall.nix];

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

  config = {
    laplace.tailnet.nodes = {
      hermes = {ip = "100.64.0.5"; ip6 = "fd7a:115c:a1e0::5"; tags = ["dns" "infra"];}; # AdGuard = tailnet resolver
      mneme = {ip = "100.64.0.6"; ip6 = "fd7a:115c:a1e0::6"; tags = ["photos" "infra"];}; # Immich
      mimir = {ip = "100.64.0.8"; ip6 = "fd7a:115c:a1e0::8"; tags = ["apps" "monitor" "infra"];}; # miniflux/silverbullet/vikunja + beszel-hub
      loki = {ip = "100.64.0.12"; ip6 = "fd7a:115c:a1e0::c"; tags = ["game"];}; # Minecraft (untrusted modpack)
      charon = {ip = "100.64.0.3"; ip6 = "fd7a:115c:a1e0::3"; tags = ["exit"];}; # exit node
      phobos = {ip = "100.64.0.1"; ip6 = "fd7a:115c:a1e0::1"; tags = ["workstation"];}; # workstation (laptop)
      deimos = {ip = "100.64.0.4"; ip6 = "fd7a:115c:a1e0::4"; tags = ["workstation"];}; # workstation (PC)
      phone = {ip = "100.64.0.2"; ip6 = "fd7a:115c:a1e0::2"; tags = ["phone"];}; # tag:phone (current mobile)
      device = {ip = "100.64.0.7"; ip6 = "fd7a:115c:a1e0::7"; tags = ["phone"];}; # tag:phone (old phone)
    };

    # §5 matrix. "phone" intentionally gets only the "*" flows (dns, monitor) for
    # now; its app reach is a deliberate policy decision still pending (today it
    # rides the throwaway admin-parity hook in the bifrost ACL).
    laplace.tailnet.flows = [
      {from = "*"; to = "dns"; ports = ["udp/53" "tcp/53"];} # override_local_dns: all -> AdGuard
      {from = "*"; to = "monitor"; ports = ["tcp/443"];} # beszel agents -> mimir hub
      {from = "workstation"; to = "apps"; ports = ["tcp/443"];}
      {from = "workstation"; to = "photos"; ports = ["tcp/443"];}
      {from = "workstation"; to = "dns"; ports = ["tcp/443"];} # AdGuard UI
      {from = "workstation"; to = "exit"; ports = ["*"];} # exit-node egress (admin only)
    ];

    laplace.tailnet.guests = {
      minecraft = {
        users = ["tom" "olivia" "ash" "anika" "mary" "esther"];
        reach = {
          game = ["tcp/25565" "udp/24454"]; # Java + Simple Voice Chat
          dns = ["udp/53"];
        };
      };
      photos = {
        users = ["sheva"];
        reach = {
          photos = ["tcp/443"];
          dns = ["udp/53"];
        };
      };
    };

    assertions = flowAsserts ++ guestAsserts ++ uniqAsserts;
  };
}
