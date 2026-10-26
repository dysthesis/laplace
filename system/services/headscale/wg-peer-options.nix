{lib}: let
  inherit (lib) mkOption types;
in {
  userId = mkOption {
    type = types.ints.positive;
    description = "Headscale user ID owning the WG-only peer.";
  };

  publicKey = mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "WG-only peer public key, as nodekey:<hex> or raw WireGuard base64, if not supplied by publicKeyFile.";
  };

  publicKeyFile = mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "Runtime file containing the WG-only peer public key, as nodekey:<hex> or raw WireGuard base64. Use this for sops-managed values.";
  };

  allowedIPs = mkOption {
    type = types.listOf types.str;
    default = ["0.0.0.0/0" "::/0"];
    description = "WireGuard AllowedIPs advertised for this peer.";
  };

  endpoints = mkOption {
    type = types.nonEmptyListOf types.str;
    description = "WireGuard relay endpoints as IP:port values.";
  };

  exitNodeDNSResolvers = mkOption {
    type = types.listOf types.str;
    default = [];
    description = "DNS resolvers pushed when this WG-only peer is used as an exit node.";
  };

  suggestExitNode = mkOption {
    type = types.nullOr types.bool;
    default = null;
    description = "Whether clients should see this peer as a suggested exit node.";
  };

  tags = mkOption {
    type = types.listOf types.str;
    default = [];
    description = "Tags placed on the synthetic WG-only node. Include the tag: prefix.";
  };

  location = mkOption {
    type = types.nullOr (types.submodule {
      options = {
        country = mkOption {type = types.str;};
        countryCode = mkOption {type = types.str;};
        city = mkOption {type = types.str;};
        cityCode = mkOption {type = types.str;};
        latitude = mkOption {type = types.float;};
        longitude = mkOption {type = types.float;};
        priority = mkOption {type = types.int;};
      };
    });
    default = null;
    description = "Exit-node location metadata.";
  };

  connections = mkOption {
    default = {};
    description = "Headscale node name -> per-node Mullvad masquerade address assignment.";
    type = types.attrsOf (types.submodule {
      options = {
        registeredNodeKey = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Expected live Headscale node key already registered with Mullvad. Null disables rotation guard.";
        };

        ipv4MasqAddr = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Mullvad-assigned IPv4 address for this Headscale node, without CIDR.";
        };

        ipv6MasqAddr = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Mullvad-assigned IPv6 address for this Headscale node, without CIDR.";
        };
      };
    });
  };
}
