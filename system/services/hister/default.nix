# Hister — self-hosted web history search. Same shape as mimir's other tenants
# (miniflux/wallabag/silverbullet): single Go binary on loopback, node-local
# Caddy terminates TLS, :443 tailnet-only. Semantic search is an optional CPU
# llama.cpp embedding sidecar (stock nixpkgs `services.llama-cpp`, NOT the
# ROCm-flavoured `laplace.services.llm` — see PLAN.md rejected alternatives).
{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.hister;
  inherit (lib) mkEnableOption mkIf mkOption optionalAttrs types;
  dataDir = "/var/lib/hister"; # upstream StateDirectory=hister default
  datasetDir = "${dataDir}/datasets";
in {
  imports = [inputs.hister.nixosModules.hister];

  options.laplace.services.hister = {
    enable = mkEnableOption "Hister, self-hosted web history search";

    domain = mkOption {
      type = types.str;
      example = "hister.example.com";
      description = "Public origin (base_url). Node-local Caddy terminates TLS and proxies to {option}`port`.";
    };

    port = mkOption {
      type = types.port;
      default = 4433;
      description = "Loopback HTTP port hister listens on.";
    };

    datasets = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["python" "rust"];
      description = ''
        Dataset slugs from <https://hister.org/datasets>, pulled weekly and
        imported. The slug is the `<name>` in `/data/<name>.json.7z`.
      '';
    };

    embedding = {
      enable = mkEnableOption "semantic search via a local CPU llama.cpp embedding server";
      port = mkOption {
        type = types.port;
        default = 8091; # 8090 is beszel on mimir
        description = "Loopback port for the llama.cpp embedding server.";
      };
    };
  };

  config = mkIf cfg.enable {
    mnemosyne.dirs = [dataDir];

    # No app.access_token: with an empty token hister leaves every endpoint
    # unauthenticated (server.go registerEndpoints wraps nothing, createHandler
    # sets Authenticated=true). The instance is single-user and reachable only
    # over the tailnet (:443 via node-local Caddy, tailscale-gated), so the
    # token would add a password prompt with no security gain — worse with
    # cookie-wiping browsers that drop the session every restart. Re-add auth by
    # setting an `app.access_token` (via environmentFile, secret-safe) if this
    # ever leaves the tailnet.
    services.hister = {
      enable = true;
      # Deliberately NOT using upstream `port`/`dataDir` options: the settings
      # block is the single source. Upstream `port` only adds firewall +
      # CAP_NET_BIND_SERVICE handling we don't want (loopback + Caddy). Upstream
      # `dataDir` would swap StateDirectory for a bare ReadWritePaths that isn't
      # auto-created; StateDirectory=hister (dataDir=null) makes the dir for us.
      settings =
        {
          # Set app.directory explicitly rather than leaning on the binary's
          # system-user permission-error fallback (config.go:590): with
          # StateDirectory=hister this path exists and is writable, so
          # MkdirAll succeeds on the first try, no scary warning log.
          app.directory = dataDir;
          server = {
            address = "127.0.0.1:${toString cfg.port}";
            base_url = "https://${cfg.domain}";
            database = "db.sqlite3"; # relative to app.directory
          };
          # crawler.backend left at its `http` default; chromedp is a per-crawl
          # CLI decision later (separate process, server unit stays hardened).
        }
        # optionalAttrs, not a nested mkIf: mkIf inside a freeform-YAML value
        # would render its {_type="if";...} wrapper into the config.
        // optionalAttrs cfg.embedding.enable {
          semantic_search = {
            enable = true;
            embedding_endpoint = "http://127.0.0.1:${toString cfg.embedding.port}/v1/embeddings";
            embedding_model = "nomic-embed-text-v1.5";
            dimensions = 768;
            max_context_length = 2048;
            # nomic-embed-text-v1.5 needs task prefixes for full retrieval quality.
            query_prefix = "search_query: ";
            document_prefix = "search_document: ";
            max_embedding_concurrency = 2; # don't peg mimir's 2 vCPU
          };
        };
    };

    # Order the server after the embedder so first-boot captures can embed;
    # `wants` (not `requires`) so hister still starts + keyword-searches if the
    # embedder is down.
    systemd.services.hister = mkIf cfg.embedding.enable {
      after = ["llama-cpp.service"];
      wants = ["llama-cpp.service"];
    };

    # Plain CPU llama.cpp (stock nixpkgs module). ~146 MB Q8_0 GGUF, declaratively
    # fetched. `--embedding` (singular) is the correct flag for this llama.cpp —
    # confirmed against laplace's own llm module, which serves nomic the same way.
    services.llama-cpp = mkIf cfg.embedding.enable {
      enable = true;
      host = "127.0.0.1";
      port = cfg.embedding.port;
      model = pkgs.fetchurl {
        url = "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf";
        sha256 = "sha256-PiQ0IWSz2UmRupaS/cDdCOP9c2Lgqsw5appcVKVEw7c=";
      };
      extraFlags = [
        "--embedding"
        "--ctx-size"
        "2048"
        "--alias"
        "nomic-embed-text-v1.5"
      ];
    };

    systemd.services.hister-datasets = mkIf (cfg.datasets != []) {
      description = "Pull + import hister datasets";
      after = ["hister.service" "network-online.target"];
      requires = ["hister.service"];
      wants = ["network-online.target"];
      path = [pkgs.curl pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        User = config.services.hister.user;
        Group = config.services.hister.group;
        # No EnvironmentFile: the server is tokenless (see above), so the import
        # CLI needs no credential — only HISTER_CONFIG for the server address.
        StateDirectory = "hister/datasets"; # -> /var/lib/hister/datasets
        PrivateTmp = true;
      };
      environment = {
        # Reuse the exact store-rendered config the server runs with, so the CLI
        # client resolves server.address identically (the upstream module sets
        # HISTER_CONFIG here whenever settings != {}).
        HISTER_CONFIG = config.systemd.services.hister.environment.HISTER_CONFIG;
      };
      script = ''
        set -euo pipefail
        cd ${datasetDir}
        for name in ${lib.escapeShellArgs cfg.datasets}; do
          # simplification: no per-dataset checksum — TLS to hister.org is the
          # trust anchor; upgrade path is pinning sha256 once upstream publishes
          # them. Datasets are mutated in place upstream ~monthly, so ETag makes
          # unchanged weekly re-runs a no-op (304 -> empty tmp -> skip import),
          # which also sidesteps re-import churn.
          if curl -fsSL \
              --etag-compare "$name.etag" --etag-save "$name.etag" \
              -o "$name.json.7z.tmp" \
              "https://hister.org/data/$name.json.7z"; then
            if [ -s "$name.json.7z.tmp" ]; then
              mv -f "$name.json.7z.tmp" "$name.json.7z"
              ${lib.getExe config.services.hister.package} import "$name.json.7z"
            else
              rm -f "$name.json.7z.tmp" # 304 Not Modified: nothing new
            fi
          fi
        done
      '';
    };

    systemd.timers.hister-datasets = mkIf (cfg.datasets != []) {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
