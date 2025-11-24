{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption types mkOption;
in {
  options.laplace.services.llm = {
    enable =
      mkEnableOption
      "Whether or not to enable local LLM hosting via llama-cpp";

    dataDir = mkOption {
      default = "/var/cache/llm";
      type = types.str;
      description = "Where to store states to persist";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address on which llama-cpp should listen";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port exposed by the llama-cpp";
    };

    search = {
      enable =
        mkEnableOption
        "Whether or not to enable local LLM search via Perplexica";

      dataDir = mkOption {
        type = types.str;
        default = "${config.laplace.services.llm.dataDir}/perplexity";
        description = "Persistent directory for Perplexica config and data";
      };

      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address on which Perplexica should listen";
      };

      port = mkOption {
        type = types.port;
        default = 3000;
        description = "Port exposed by the Perplexica web service";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to open the firewall for the Perplexica port";
      };

      image = mkOption {
        type = types.str;
        default = "docker.io/itzcrazykns1337/perplexica:slim-latest";
        description = "OCI image used to run Perplexica";
      };

      settings = {
        similarityMeasure = mkOption {
          type = types.enum ["cosine" "dot"];
          default = "cosine";
          description = "Similarity measurement method";
        };

        keepAlive = mkOption {
          type = types.str;
          default = "5m";
          description = "Idle timeout for LLM back-ends (Perplexica KEEP_ALIVE)";
        };

        searxngUrl = mkOption {
          type = types.str;
          default = "http://host.containers.internal:8100";
          description = "Base URL where SearXNG is exposed for Perplexica";
        };

        customOpenAI = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              apiUrl = mkOption {
                type = types.str;
                description = "OpenAI-compatible endpoint (e.g., llama-cpp server)";
              };

              apiKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional API key for the custom endpoint";
              };

              modelName = mkOption {
                type = types.str;
                default = "gpt-4o-mini";
                description = "Model name advertised by the custom endpoint";
              };
            };
          });
          default = null;
          description = "Custom OpenAI-compatible provider used by Perplexica";
        };

        openai = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              apiKey = mkOption {
                type = types.str;
                description = "OpenAI API key";
              };

              organization = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional OpenAI organisation";
              };
            };
          });
          default = null;
          description = "OpenAI provider credentials for Perplexica";
        };

        ollama = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              apiUrl = mkOption {
                type = types.str;
                description = "Ollama base URL";
              };

              apiKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional Ollama API key";
              };
            };
          });
          default = null;
          description = "Ollama provider for Perplexica";
        };
      };
    };
  };
}
