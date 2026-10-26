{
  lib,
  catalogue,
  ...
}: let
  inherit (lib) mkOption types;
  option = type: default: mkOption {inherit type default;};
  required = type: mkOption {inherit type;};
  name = types.strMatching "[a-z][a-z0-9-]*";
  address = types.strMatching "[^ /]+";
  tailnet = types.submodule {
    options = {
      ip = required address;
      ip6 = required address;
      tags = required (types.listOf name);
    };
  };
  principal = types.submodule {
    options = {
      role = option (types.nullOr name) null;
      guest = option (types.nullOr name) null;
      node = option (types.nullOr name) null;
      service = option (types.nullOr name) null;
      knownNodes = option types.bool false;
    };
  };
  portToken = types.strMatching "(\\*|(tcp|udp)/[0-9]+(-[0-9]+)?)";
  endpointRef = types.submodule {
    options = {
      service = required name;
      endpoint = required name;
    };
  };
in {
  options.laplace = {
    hosts = option (types.attrsOf (types.submodule ({config, ...}: {
      options = {
        system = required types.str;
        role = required (types.enum ["server" "workstation" "installer"]);
        lan.ip = option (types.nullOr address) null;
        deployment =
          option (types.nullOr (types.submodule {
            options = {
              targetHost = option (types.nullOr address) config.lan.ip;
              targetUser = option types.str "root";
              buildOnTarget = option types.bool false;
            };
          }))
          null;
        tailnet = option (types.nullOr tailnet) null;
        trust = required (types.enum ["trusted" "game" "ci" "git" "control-plane" "edge" "client"]);
        storage = option (types.listOf (types.enum ["persistent" "btrfs" "observability-volumes" "media" "photos"])) [];
        telemetry = option types.bool false;
        beszel = option (types.nullOr (types.enum ["push" "pull"])) null;
        caddy = option types.bool false;
        dnsListenerAvailable = option types.bool false;
      };
    }))) {};
    services = lib.mapAttrs (_: recipe:
      option (types.nullOr (types.submodule {
        options = {
          enable = option types.bool true;
          host = required name;
          settings = option (types.submodule {options = recipe.settings;}) {};
        };
      }))
      null)
    catalogue;
    tailnet = {
      peers = option (types.attrsOf tailnet) {};
      guests = option (types.attrsOf (types.submodule {
        options.users = required (types.listOf name);
      })) {};
      nodeFlows = option (types.listOf (types.submodule {
        options = {
          from = required principal;
          to = required principal;
          ports = required (types.listOf portToken);
          forwarding = option types.bool false;
        };
      })) [];
      serviceGrants = option (types.listOf (types.submodule {
        options = {
          from = required principal;
          to = required endpointRef;
        };
      })) [];
      staticRecords = option (types.listOf (types.submodule {
        options = {
          name = required types.str;
          node = required name;
          reason = required types.nonEmptyStr;
        };
      })) [];
    };
  };
}
