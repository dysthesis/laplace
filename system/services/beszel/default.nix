# WS mode: agents push with a KEY and TOKEN.
# SSH mode: the hub pulls with public-key auth from hosts that must not reach it.
# The hub binds loopback behind Caddy.
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
      mode = mkOption {
        type = types.enum ["push" "pull"];
        default = "push";
        description = "Machine-side connection mode; cluster supplies the hub endpoint and identity.";
      };

      # Agent pushes to hub.
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

      # Hub pulls from agent.
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
      # Persist DynamicUser's private directory; it holds accounts and the hub SSH key.
      mnemosyne.dirs = ["/var/lib/private/beszel-hub"];

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

      # Push mode needs no inbound port.
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

      # Pull mode accepts only the hub IP.
      (mkIf (cfg.agent.key != null) {
        assertions = [
          {
            assertion = cfg.agent.trustedHubs != [];
            message = "laplace.services.beszel.agent SSH mode (key set) needs trustedHubs — the hub's source IP(s); without it the host firewall drops the hub and the agent is unreachable.";
          }
          {
            # Pull-mode scoping requires nftables extraInputRules.
            assertion = !config.networking.firewall.enable || config.networking.firewall.backend == "nftables";
            message = "laplace.services.beszel.agent SSH mode emits a scoped nftables input rule, but this host's firewall backend is iptables, where networking.firewall.extraInputRules is ignored — the listen port would be left unreachable. Set networking.nftables.enable = true (safe without Docker).";
          }
        ];
        services.beszel.agent = {
          openFirewall = false;
          environment = {
            KEY = cfg.agent.key;
            LISTEN = cfg.agent.listen;
            # Persist the agent SSH key or the hub's pinned fingerprint breaks.
            DATA_DIR = "/var/lib/beszel-agent";
          };
        };

        # Use a static user and persisted StateDirectory for a stable SSH key path.
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
