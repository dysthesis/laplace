{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    types
    mkOption
    ;
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

    modelRegistry = mkOption {
      type =
        types.attrsOf
        (types.submodule ({name, ...}: {
          options = {
            url = mkOption {
              type = types.str;
              description = "Source URL for the ${name} model artifact";
            };

            sha256 = mkOption {
              type = types.str;
              description = "SRI or base32 SHA-256 hash of the ${name} model";
            };
          };
        }));

      default = {
        qwen3 = {
          url = "https://huggingface.co/unsloth/Qwen3-8B-GGUF/resolve/main/Qwen3-8B-Q4_K_M.gguf";
          sha256 = "sha256-EgMHulKeskOdbEMNlBBNq9V4SXvHv+fjIrXZkztEm9Q=";
        };
      };

      description = "List of models to pull";
    };

    model = mkOption {
      type =
        types.enum
        (builtins.attrNames config.laplace.services.llm.modelRegistry);

      default = "qwen3";

      description = "Which model to choose";
    };

    contextSize = mkOption {
      type = types.int;
      default = 4096;
      description = "Context size of llama-cpp";
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
                default = config.laplace.services.llm.model;
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

    webui = {
      enable =
        mkEnableOption
        "Whether or not to enable Open WebUI for the local llama-cpp service";

      stateDir = mkOption {
        type = types.path;
        default = "/var/lib/open-webui";
        description = "State directory used by Open WebUI";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address on which Open WebUI should listen";
      };

      port = mkOption {
        type = types.port;
        default = 8081;
        description = "Port exposed by the Open WebUI web service";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to open the firewall for the Open WebUI port";
      };

      apiUrl = mkOption {
        type = types.str;
        default = let
          host = config.laplace.services.llm.host;
          resolvedHost =
            if host == "0.0.0.0"
            then "127.0.0.1"
            else if builtins.elem host ["::" "[::]"]
            then "[::1]"
            else if lib.hasInfix ":" host && !(lib.hasPrefix "[" host)
            then "[${host}]"
            else host;
        in "http://${resolvedHost}:${toString config.laplace.services.llm.port}/v1";
        description = "OpenAI-compatible URL Open WebUI should use for llama-cpp (include `/v1`)";
      };

      apiKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional API key passed to the OpenAI-compatible llama-cpp endpoint";
      };

      enableOllama = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to keep the built-in Ollama provider enabled in Open WebUI";
      };

      modelListTimeout = mkOption {
        type = types.nullOr types.int;
        default = 30;
        description = "Timeout in seconds for fetching provider model lists in Open WebUI";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Additional environment variables passed to Open WebUI";
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Optional environment file with extra Open WebUI settings or secrets";
      };
    };
  };
}
