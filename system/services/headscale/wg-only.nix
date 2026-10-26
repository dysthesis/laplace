{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) all attrValues concatMap mapAttrsToList mkEnableOption mkIf mkOption optionalAttrs types unique;

  cfg = config.laplace.services.headscale.wgOnly;

  publicKeySet = peer: (peer.publicKey != null) != (peer.publicKeyFile != null);
  tagOk = tag: lib.hasPrefix "tag:" tag;
  noCidr = addr: addr == null || !(lib.hasInfix "/" addr);
  endpointOk = endpoint: builtins.match ".+:[0-9]+" endpoint != null;
  masqAddrs = peer:
    concatMap (conn: lib.optionals (conn.ipv4MasqAddr != null) [conn.ipv4MasqAddr] ++ lib.optionals (conn.ipv6MasqAddr != null) [conn.ipv6MasqAddr])
    (attrValues peer.connections);
  peerExtraConfig = peer:
    optionalAttrs (peer.exitNodeDNSResolvers != []) {inherit (peer) exitNodeDNSResolvers;}
    // optionalAttrs (peer.suggestExitNode != null) {inherit (peer) suggestExitNode;}
    // optionalAttrs (peer.tags != []) {inherit (peer) tags;}
    // optionalAttrs (peer.location != null) {inherit (peer) location;};

  desired = {
    peers =
      mapAttrsToList (name: peer: {
        inherit name;
        inherit (peer) userId publicKey publicKeyFile allowedIPs endpoints;
        extraConfig = peerExtraConfig peer;
        connections =
          mapAttrsToList (nodeName: conn: {
            inherit nodeName;
            inherit (conn) registeredNodeKey ipv4MasqAddr ipv6MasqAddr;
          })
          peer.connections;
      })
      cfg.peers;
  };

  desiredFile = pkgs.writeText "headscale-wg-only.json" (builtins.toJSON desired);

  reconcile = pkgs.writeShellApplication {
    name = "headscale-wg-only-reconcile";
    runtimeInputs = [
      config.services.headscale.package
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
      pkgs.sqlite
    ];
    text = ''
      set -euo pipefail

      desired_file=${lib.escapeShellArg desiredFile}
      config_file=${lib.escapeShellArg config.services.headscale.configFile}
      db=${lib.escapeShellArg cfg.databasePath}

      hs() {
        headscale --config "$config_file" --force "$@"
      }

      read_peers() {
        sqlite3 -readonly -json "$db" '
          select
            id,
            name,
            user_id as userId,
            public_key as publicKey,
            allowed_ips as allowedIPs,
            endpoints,
            extra_config as extraConfig
          from wireguard_only_peers
          where deleted_at is null;
        '
      }

      read_connections() {
        sqlite3 -readonly -json "$db" '
          select
            node_id as nodeId,
            wg_peer_id as wgPeerId,
            ipv4_masq_addr as ipv4MasqAddr,
            ipv6_masq_addr as ipv6MasqAddr
          from node_wg_peer_connections;
        '
      }

      canon_array() {
        jq -c 'sort' <<<"$1"
      }

      canon_obj() {
        if [ -z "$1" ] || [ "$1" = "null" ]; then
          printf '{}'
        else
          jq -cS '
            if .location? then
              .location = {
                country: (.location.country // .location.Country),
                countryCode: (.location.countryCode // .location.CountryCode),
                city: (.location.city // .location.City),
                cityCode: (.location.cityCode // .location.CityCode),
                latitude: (.location.latitude // .location.Latitude),
                longitude: (.location.longitude // .location.Longitude),
                priority: (.location.priority // .location.Priority)
              }
            else
              .
            end
          ' <<<"$1"
        fi
      }

      fail_drift() {
        local name=$1 field=$2 live=$3 want=$4
        printf 'headscale wg-only peer drift: %s %s live=%s want=%s\n' "$name" "$field" "$live" "$want" >&2
        exit 1
      }

      normalise_public_key() {
        local key=$1 hex
        if [[ "$key" == nodekey:* ]]; then
          printf '%s' "$key"
          return
        fi

        if ! hex=$(printf '%s' "$key" | base64 -d 2>/dev/null | od -An -tx1 -v | tr -d ' \n'); then
          printf 'headscale wg-only peer public key must be nodekey:<hex> or raw WireGuard base64\n' >&2
          exit 1
        fi
        if [ "''${#hex}" -ne 64 ]; then
          printf 'headscale wg-only peer public key must be nodekey:<hex> or raw WireGuard base64\n' >&2
          exit 1
        fi
        printf 'nodekey:%s' "$hex"
      }

      peer_public_key() {
        local peer=$1 public_key public_key_file
        public_key=$(jq -r '.publicKey // ""' <<<"$peer")
        public_key_file=$(jq -r '.publicKeyFile // ""' <<<"$peer")
        if [ -n "$public_key_file" ]; then
          if [ ! -r "$public_key_file" ]; then
            printf 'headscale wg-only peer public key file unreadable: %s\n' "$public_key_file" >&2
            exit 1
          fi
          public_key=$(tr -d '[:space:]' < "$public_key_file")
        fi
        if [ -z "$public_key" ]; then
          printf 'headscale wg-only peer public key empty\n' >&2
          exit 1
        fi
        normalise_public_key "$public_key"
      }

      find_node() {
        local name=$1
        jq -c --arg name "$name" 'first(.[] | select((.given_name // .givenName // .name) == $name)) // empty' <<<"$nodes_json"
      }

      nodes_json=$(hs -o json nodes list)
      peers_json=$(read_peers)
      connections_json=$(read_connections)

      while IFS= read -r peer; do
        name=$(jq -r '.name' <<<"$peer")
        user_id=$(jq -r '.userId | tostring' <<<"$peer")
        public_key=$(peer_public_key "$peer")
        allowed_ips=$(jq -r '.allowedIPs | join(",")' <<<"$peer")
        endpoints=$(jq -r '.endpoints | join(",")' <<<"$peer")
        extra_config=$(jq -c '.extraConfig' <<<"$peer")

        live_peer=$(jq -c --arg name "$name" 'first(.[] | select(.name == $name)) // empty' <<<"$peers_json")
        if [ -z "$live_peer" ]; then
          args=(nodes register-wg-only --name "$name" --user "$user_id" --public-key "$public_key" --allowed-ips "$allowed_ips" --endpoints "$endpoints")
          if [ "$extra_config" != "{}" ]; then
            args+=(--extra-config "$extra_config")
          fi
          hs -o json "''${args[@]}" >/dev/null
          peers_json=$(read_peers)
          live_peer=$(jq -c --arg name "$name" 'first(.[] | select(.name == $name)) // empty' <<<"$peers_json")
          if [ -z "$live_peer" ]; then
            printf 'headscale wg-only peer registration vanished: %s\n' "$name" >&2
            exit 1
          fi
        fi

        peer_id=$(jq -r '.id' <<<"$live_peer")
        live_user_id=$(jq -r '.userId | tostring' <<<"$live_peer")
        live_public_key=$(jq -r '.publicKey' <<<"$live_peer")
        live_allowed=$(canon_array "$(jq -r '.allowedIPs' <<<"$live_peer")")
        want_allowed=$(jq -c '.allowedIPs | sort' <<<"$peer")
        live_endpoints=$(canon_array "$(jq -r '.endpoints' <<<"$live_peer")")
        want_endpoints=$(jq -c '.endpoints | sort' <<<"$peer")
        live_extra=$(canon_obj "$(jq -r '.extraConfig // ""' <<<"$live_peer")")
        want_extra=$(canon_obj "$(jq -c '.extraConfig' <<<"$peer")")

        [ "$live_user_id" = "$user_id" ] || fail_drift "$name" userId "$live_user_id" "$user_id"
        [ "$live_public_key" = "$public_key" ] || fail_drift "$name" publicKey "$live_public_key" '<runtime public key>'
        [ "$live_allowed" = "$want_allowed" ] || fail_drift "$name" allowedIPs "$live_allowed" "$want_allowed"
        [ "$live_endpoints" = "$want_endpoints" ] || fail_drift "$name" endpoints "$live_endpoints" "$want_endpoints"
        [ "$live_extra" = "$want_extra" ] || fail_drift "$name" extraConfig "$live_extra" "$want_extra"

        declared_node_ids=$(mktemp)
        while IFS= read -r conn; do
          node_name=$(jq -r '.nodeName' <<<"$conn")
          node=$(find_node "$node_name")
          if [ -z "$node" ]; then
            printf 'headscale wg-only connection node missing: peer=%s node=%s\n' "$name" "$node_name" >&2
            exit 1
          fi

          node_id=$(jq -r '.id' <<<"$node")
          printf '%s\n' "$node_id" >> "$declared_node_ids"

          want_node_key=$(jq -r '.registeredNodeKey // ""' <<<"$conn")
          if [ -n "$want_node_key" ]; then
            live_node_key=$(jq -r '.nodeKey // .node_key // ""' <<<"$node")
            if [ "$live_node_key" != "$want_node_key" ]; then
              printf 'headscale wg-only node key drift: node=%s live=%s want=%s\n' "$node_name" "$live_node_key" "$want_node_key" >&2
              exit 1
            fi
          fi

          want_v4=$(jq -r '.ipv4MasqAddr // ""' <<<"$conn")
          want_v6=$(jq -r '.ipv6MasqAddr // ""' <<<"$conn")
          live_conn=$(jq -c --argjson nodeId "$node_id" --argjson wgPeerId "$peer_id" 'first(.[] | select(.nodeId == $nodeId and .wgPeerId == $wgPeerId)) // empty' <<<"$connections_json")
          if [ -n "$live_conn" ]; then
            live_v4=$(jq -r '.ipv4MasqAddr // ""' <<<"$live_conn")
            live_v6=$(jq -r '.ipv6MasqAddr // ""' <<<"$live_conn")
            if [ "$live_v4" != "$want_v4" ] || [ "$live_v6" != "$want_v6" ]; then
              hs -o json nodes remove-wg-connection --node-id "$node_id" --wg-peer-id "$peer_id" >/dev/null
              live_conn=""
            fi
          fi

          if [ -z "$live_conn" ]; then
            args=(nodes add-wg-connection --node-id "$node_id" --wg-peer-id "$peer_id")
            if [ -n "$want_v4" ]; then
              args+=(--ipv4-masq-addr "$want_v4")
            fi
            if [ -n "$want_v6" ]; then
              args+=(--ipv6-masq-addr "$want_v6")
            fi
            hs -o json "''${args[@]}" >/dev/null
          fi
        done < <(jq -c '.connections[]' <<<"$peer")

        while IFS= read -r live_conn; do
          live_node_id=$(jq -r '.nodeId' <<<"$live_conn")
          if ! grep -qx "$live_node_id" "$declared_node_ids"; then
            hs -o json nodes remove-wg-connection --node-id "$live_node_id" --wg-peer-id "$peer_id" >/dev/null
          fi
        done < <(jq -c --argjson wgPeerId "$peer_id" '.[] | select(.wgPeerId == $wgPeerId)' <<<"$connections_json")
        rm -f "$declared_node_ids"
      done < <(jq -c '.peers[]' "$desired_file")
    '';
  };
in {
  options.laplace.services.headscale.wgOnly = {
    enable = mkEnableOption "declarative Headscale WireGuard-only peers";

    databasePath = mkOption {
      type = types.path;
      default = config.services.headscale.settings.database.sqlite.path;
      description = "Headscale SQLite database used for read-side WG-only reconciliation.";
    };

    peers = mkOption {
      default = {};
      description = ''
        WireGuard-only peers keyed by Headscale peer name. These peers bypass ACLs;
        only declared connections can see them.'';
      type = types.attrsOf (types.submodule {
        options = import ./wg-peer-options.nix {inherit lib;};
      });
    };

    desiredFile = mkOption {
      type = types.path;
      readOnly = true;
      default = desiredFile;
      description = "Rendered non-secret desired WG-only state.";
    };
  };

  config = mkIf (config.laplace.services.headscale.enable && cfg.enable) {
    assertions =
      [
        {
          assertion = cfg.peers != {};
          message = "laplace.services.headscale.wgOnly.enable is on but no peers are declared";
        }
      ]
      ++ concatMap (peerName: let
        peer = cfg.peers.${peerName};
        addrs = masqAddrs peer;
      in
        [
          {
            assertion = publicKeySet peer;
            message = "laplace.services.headscale.wgOnly.peers.${peerName}: set exactly one of publicKey or publicKeyFile";
          }
          {
            assertion = all endpointOk peer.endpoints;
            message = "laplace.services.headscale.wgOnly.peers.${peerName}: endpoints must be IP:port strings";
          }
          {
            assertion = all tagOk peer.tags;
            message = "laplace.services.headscale.wgOnly.peers.${peerName}: tags must include the tag: prefix";
          }
          {
            assertion = addrs == unique addrs;
            message = "laplace.services.headscale.wgOnly.peers.${peerName}: duplicate masquerade address";
          }
        ]
        ++ concatMap (nodeName: let
          conn = peer.connections.${nodeName};
        in [
          {
            assertion = conn.ipv4MasqAddr != null || conn.ipv6MasqAddr != null;
            message = "laplace.services.headscale.wgOnly.peers.${peerName}.connections.${nodeName}: at least one masquerade address is required";
          }
          {
            assertion = noCidr conn.ipv4MasqAddr && noCidr conn.ipv6MasqAddr;
            message = "laplace.services.headscale.wgOnly.peers.${peerName}.connections.${nodeName}: masquerade addresses must not include CIDR";
          }
        ]) (builtins.attrNames peer.connections)) (builtins.attrNames cfg.peers);

    systemd.services.headscale-wg-only-reconcile = {
      description = "Reconcile declarative Headscale WireGuard-only peers";
      wantedBy = ["multi-user.target"];
      requires = ["headscale.service"];
      after = ["headscale.service" "sops-nix.service"];
      restartTriggers = [desiredFile config.services.headscale.configFile];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
      };
      script = ''
        exec ${reconcile}/bin/headscale-wg-only-reconcile
      '';
    };
  };
}
