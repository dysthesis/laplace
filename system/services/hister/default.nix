# Tailnet-only Hister service with optional CPU embeddings.
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

    # Tailnet access is the auth boundary; an app token adds no isolation here.
    # Add a secret access_token before exposing Hister elsewhere.
    services.hister = {
      enable = true;
      # Keep settings authoritative; upstream port opens the firewall and dataDir
      # replaces auto-created StateDirectory with a bare path.
      settings =
        {
          # Use the writable StateDirectory directly; avoid the permission fallback.
          app.directory = dataDir;
          server = {
            address = "127.0.0.1:${toString cfg.port}";
            base_url = "https://${cfg.domain}";
            database = "db.sqlite3"; # relative to app.directory
          };
          # Keep chromedp as a separate per-crawl process.
        }
        # nested mkIf would leak its wrapper into freeform YAML.
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

    # Serve the pinned embedding model with the CPU llama.cpp module.
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

    # Start after the embedder, but allow keyword search when it is down.
    systemd = {
      services = {
        hister = mkIf cfg.embedding.enable {
          after = ["llama-cpp.service"];
          wants = ["llama-cpp.service"];
        };

        hister-datasets = mkIf (cfg.datasets != []) {
          description = "Pull + import hister datasets";
          after = ["hister.service" "network-online.target"];
          requires = ["hister.service"];
          wants = ["network-online.target"];
          path = [pkgs.curl pkgs.coreutils];
          serviceConfig = {
            Type = "oneshot";
            User = config.services.hister.user;
            Group = config.services.hister.group;
            # Tokenless imports need only HISTER_CONFIG.
            StateDirectory = "hister/datasets"; # -> /var/lib/hister/datasets
            PrivateTmp = true;
          };
          environment = {
            # Reuse the server's rendered config for the CLI address.
            HISTER_CONFIG = config.systemd.services.hister.environment.HISTER_CONFIG;
          };
          script = ''
            set -euo pipefail
            cd ${datasetDir}
            for name in ${lib.escapeShellArgs cfg.datasets}; do
              # simplification: trust TLS until upstream publishes checksums.
              # ETag makes unchanged weekly downloads no-ops.
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
      };

      timers.hister-datasets = mkIf (cfg.datasets != []) {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    };
  };
}
