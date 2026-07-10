{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types optionalAttrs mapAttrs' mapAttrsToList filterAttrs nameValuePair;
  cfg = config.laplace.services.headscale.acl;

  # Policy v2 names a local user by "<username>@" (the part after @ is the OIDC
  # domain, empty for headscale-local users).
  userRef = u: "${u}@";

  # Each declared group becomes a "group:<name>" -> [members] entry...
  groups = mapAttrs' (n: g: nameValuePair "group:${n}" (map userRef g.members)) cfg.groups;

  # ...and one accept rule "group:<name> -> destinations". Groups with no
  # destinations emit no rule (members exist but reach nothing - a valid holding
  # state), so we never emit a rule with an empty dst.
  groupRules = mapAttrsToList (n: g: {
    action = "accept";
    src = ["group:${n}"];
    dst = g.destinations;
  }) (filterAttrs (_: g: g.destinations != []) cfg.groups);

  acls =
    groupRules
    # Raw escape hatch for sources that are not a group (tags, CIDRs, ...).
    # Rebuilt explicitly so submodule internals never leak into the JSON.
    ++ map (r: {inherit (r) action src dst;}) cfg.rules;

  policy =
    {inherit acls;}
    // optionalAttrs (groups != {}) {inherit groups;}
    // optionalAttrs (cfg.hosts != {}) {inherit (cfg) hosts;}
    // optionalAttrs (cfg.tagOwners != {}) {inherit (cfg) tagOwners;}
    // optionalAttrs (cfg.autoApprovers != {}) {inherit (cfg) autoApprovers;};

  # JSON is valid HuJSON and toJSON guarantees well-formed output, so the only way
  # to feed headscale a policy it rejects is a semantic mistake (undefined alias,
  # empty groups), which the assertion and strict load both catch.
  policyFile = pkgs.writeText "headscale-policy.hujson" (builtins.toJSON policy);
in {
  options.laplace.services.headscale.acl = {
    enable = mkEnableOption ''
      a declarative Headscale ACL policy. Switches headscale to file-mode policy
      (default-deny - only listed flows pass), so a group must re-grant your own
      nodes a full mesh or you lock yourself out. Also makes Headplane's ACL
      editor read-only: the policy is owned by Nix, not the database'';

    groups = mkOption {
      default = {};
      description = ''
        ACL groups keyed by bare name (the `group:` prefix is added for you). Each
        is a set of member users and the destinations they may reach; this is the
        whole authorisation model.'';
      example = lib.literalExpression ''
        {
          admin.members = ["demiurge"];
          admin.destinations = ["group:admin:*"]; # full mesh among your nodes
          friends = {
            members = ["sheva"];
            destinations = ["mc:25565" "adguard:53"];
          };
        }
      '';
      type = types.attrsOf (types.submodule {
        options = {
          members = mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              Headscale usernames (no `@`) in this group; `headscale users list`
              shows them. Every device a member enrols inherits the group's access.
              A name with no matching user yet is inert, not an error.'';
          };
          destinations = mkOption {
            type = types.listOf types.str;
            default = [];
            example = ["mc:25565" "group:admin:*"];
            description = ''
              "<dst>:<port>" tokens members may reach, and nothing else. <dst> is a
              host alias from `hosts`, another `group:<name>`, a tag, a CIDR, or
              `*`. `group:<self>:*` makes the group a full mesh. An undefined host
              alias or group makes headscale reject the whole policy. Empty = the
              members reach nothing.'';
          };
        };
      });
    };

    hosts = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {mc = "100.64.0.10/32";};
      description = "Named host aliases (name -> CIDR) referenced by group destinations and rules.";
    };

    tagOwners = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {};
      description = "Headscale tagOwners (tag -> owner tokens), for tag-based rules.";
    };

    autoApprovers = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Headscale autoApprovers block (routes / exitNode), passed through verbatim.";
    };

    rules = mkOption {
      type = types.listOf (types.submodule {
        options = {
          action = mkOption {
            type = types.enum ["accept"];
            default = "accept";
            description = "Headscale only supports accept; everything unmatched is denied.";
          };
          src = mkOption {
            type = types.listOf types.str;
            description = "Source tokens (group:.../tag:.../host/<user>@/*).";
          };
          dst = mkOption {
            type = types.listOf types.str;
            description = ''"<dst>:<port>" destination tokens.'';
          };
        };
      });
      default = [];
      description = "Extra raw ACL rules for non-group sources (tags, CIDRs), appended after the group rules.";
    };

    policyFile = mkOption {
      type = types.path;
      readOnly = true;
      default = policyFile;
      description = "Rendered policy file (read-only; inspect with `headscale policy check --file <path>`).";
    };
  };

  config = mkIf (config.laplace.services.headscale.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.groups != {};
        message = "laplace.services.headscale.acl.enable is on but groups is empty: the file-mode policy would default-deny your entire tailnet. Define at least one group that meshes your own nodes (destinations = [\"group:<name>:*\"]).";
      }
    ];

    # Merges with the host's other headscale settings (server_url, dns, ...).
    services.headscale.settings.policy = {
      mode = "file";
      path = policyFile;
    };
  };
}
