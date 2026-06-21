# Beszel server monitoring: a lightweight hub (web dashboard, PocketBase-backed)
# and a per-host agent, in either of Beszel's two connection directions:
#
#   - WS / push (hubUrl + environmentFile): the agent dials OUT to the hub with a
#     KEY + TOKEN the hub minted. For hosts that can reach the hub (tailnet/LAN).
#   - SSH / pull (key + trustedHubs): the agent LISTENS; the hub dials IN with its
#     private key and pulls metrics. The agent holds only the hub's PUBLIC key — no
#     token, no sops. For hosts the hub must reach but that must not reach inward,
#     e.g. a DMZ box: the connection runs trusted→untrusted, never the reverse.
#
# KEY + TOKEN are minted by the hub on first boot (Add System / Settings → Tokens).
# The hub itself binds loopback; a node-local Caddy fronts it.
{
  config,
  lib,
  ...
}: let
  inherit (lib) concatMapStringsSep mkEnableOption mkForce mkIf mkMerge mkOption optionalAttrs types;
  cfg = config.laplace.services.beszel;
in {
  options.laplace.services.beszel = {
    hub = {
      enable = mkEnableOption "Beszel hub (server-monitoring web dashboard)";

      appUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://status.dysthesis.com";
        description = ''
          Public origin the hub is served at (APP_URL). Beszel bakes it into
          generated links and OAuth redirects, so it must match what the browser
          hits, not the bare loopback the hub binds. Null lets Beszel derive it
          from the request host.
        '';
      };
    };

    agent = {
      enable = mkEnableOption "Beszel agent (per-host metrics reporter)";

      # --- WS / push mode: the agent dials OUT to the hub. ---
      hubUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://status.dysthesis.com";
        description = ''
          WS mode: hub URL the agent dials out to (HUB_URL). Pair with
          environmentFile. For hosts that can reach the hub (tailnet/LAN).
        '';
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          WS mode: EnvironmentFile with the hub-minted KEY + TOKEN. Source it from
          sops; required when hubUrl is set.
        '';
      };

      # --- SSH / pull mode: the hub dials IN; the agent listens. ---
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "ssh-ed25519 AAAA...";
        description = ''
          SSH mode: the hub's PUBLIC SSH key (the KEY the hub's Add System dialog
          shows — same value already in your WS env files). Sets the agent's KEY
          env and selects SSH/pull mode. Public, so plain nix is fine: no token, no
          sops. The agent accepts only a client proving the matching private key,
          which lives solely on the hub. For hosts the hub must reach but that must
          not reach inward (DMZ).
        '';
      };

      listen = mkOption {
        type = types.str;
        default = "45876";
        description = "SSH mode: TCP port the agent listens on for the hub. Fed to LISTEN and the scoped firewall rule.";
      };

      trustedHubs = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["10.0.20.83"];
        description = ''
          SSH mode: source address(es) allowed to reach `listen` — the hub's IP as
          it arrives at this host (watch for NAT). Emits a scoped nftables accept;
          the port stays closed to everything else. Required in SSH mode.
        '';
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.hub.enable {
      # Real dir is /var/lib/private/beszel-hub (DynamicUser + StateDirectory),
      # with /var/lib/beszel-hub symlinked to it. Persist the real one: it holds
      # the PocketBase DB — users, configured systems, and the hub's own SSH key.
      # Lose it and every reboot wipes the account and the key agents trust.
      mnemosyne.dirs = ["/var/lib/private/beszel-hub"];

      # Binds 127.0.0.1:8090 by default; the node's own Caddy fronts TLS.
      services.beszel.hub = {
        enable = true;
        environment = optionalAttrs (cfg.hub.appUrl != null) {
          APP_URL = cfg.hub.appUrl;
        };
      };
    })

    (mkIf cfg.agent.enable (mkMerge [
      {
        assertions = [
          {
            assertion = (cfg.agent.hubUrl != null) != (cfg.agent.key != null);
            message = "laplace.services.beszel.agent needs exactly one mode: WS (hubUrl + environmentFile) or SSH (key + trustedHubs) — not both, not neither.";
          }
        ];
        services.beszel.agent.enable = true;
      }

      # WS / push: the agent dials the hub outbound, so nothing inbound to open.
      (mkIf (cfg.agent.hubUrl != null) {
        assertions = [
          {
            assertion = cfg.agent.environmentFile != null;
            message = "laplace.services.beszel.agent WS mode (hubUrl set) needs environmentFile — the sops env file with the hub-minted KEY + TOKEN.";
          }
        ];
        services.beszel.agent = {
          openFirewall = false;
          inherit (cfg.agent) environmentFile;
          environment.HUB_URL = cfg.agent.hubUrl;
        };
      })

      # SSH / pull: the hub dials in; the agent listens, scoped to the hub's IP
      # only. Never openFirewall on an exposed box — KEY auth is the lock, the
      # scoped rule is the bolt.
      (mkIf (cfg.agent.key != null) {
        assertions = [
          {
            assertion = cfg.agent.trustedHubs != [];
            message = "laplace.services.beszel.agent SSH mode (key set) needs trustedHubs — the hub's source IP(s); without it the host firewall drops the hub and the agent is unreachable.";
          }
          {
            # extraInputRules lives only in the nftables firewall; on the iptables
            # backend it is a silent no-op, leaving the listen port unreachable.
            # Fail loudly rather than ship a dead scoping rule.
            assertion = !config.networking.firewall.enable || config.networking.firewall.backend == "nftables";
            message = "laplace.services.beszel.agent SSH mode emits a scoped nftables input rule, but this host's firewall backend is iptables, where networking.firewall.extraInputRules is ignored — the listen port would be left unreachable. Set networking.nftables.enable = true (safe without Docker).";
          }
        ];
        services.beszel.agent = {
          openFirewall = false;
          environment.KEY = cfg.agent.key;
          environment.LISTEN = cfg.agent.listen;
          # The agent keeps its own SSH host key (.key) here. Without a persistent
          # dir the key is ephemeral — regenerated each restart — so the hub's
          # pinned fingerprint breaks on every deploy and the system shows "Down"
          # even though the listen port is reachable.
          environment.DATA_DIR = "/var/lib/beszel-agent";
        };

        # Make DATA_DIR real, writable under ProtectSystem=strict, and stable. The
        # static beszel-agent user already exists (for the dbus systemd-monitoring
        # policy), so run as it (DynamicUser off) to keep StateDirectory at a
        # deterministic /var/lib path rather than the DynamicUser /var/lib/private
        # indirection. Persist it so the host key — and thus the fingerprint —
        # survives reboots under impermanence.
        systemd.services.beszel-agent.serviceConfig = {
          DynamicUser = mkForce false;
          StateDirectory = "beszel-agent";
        };
        mnemosyne.dirs = ["/var/lib/beszel-agent"];

        networking.firewall.extraInputRules =
          concatMapStringsSep "\n"
          (src: "ip saddr ${src} tcp dport ${cfg.agent.listen} accept")
          cfg.agent.trustedHubs;
      })
    ]))
  ];
}
