{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    types
    mkOption
    ;

  resolveOpenAIHost = host:
    if host == "0.0.0.0"
    then "127.0.0.1"
    else if builtins.elem host ["::" "[::]"]
    then "[::1]"
    else if lib.hasInfix ":" host && !(lib.hasPrefix "[" host)
    then "[${host}]"
    else host;

  activeOpenAIEndpoint = let
    root = config.laplace.services.llm;
    backend =
      if root.backend == "vllm"
      then root.vllm
      else root;
  in "http://${resolveOpenAIHost backend.host}:${toString backend.port}/v1";

  activeModelName = let
    root = config.laplace.services.llm;
  in
    if root.backend == "vllm"
    then root.vllm.servedModelName
    else root.model;

  defaultEmbeddingModel = let
    registry = config.laplace.services.llm.modelRegistry;
  in
    if builtins.hasAttr "nomic-embed-text" registry
    then "nomic-embed-text"
    else config.laplace.services.llm.model;
in {
  options.laplace.services.llm = {
    enable =
      mkEnableOption
      "Whether or not to enable local LLM hosting";

    backend = mkOption {
      type = types.enum ["llama-cpp" "vllm"];
      default = "llama-cpp";
      description = "Local LLM backend to run";
    };

    turboquant.enable =
      mkEnableOption
      "Whether or not to enable TurboQuant support.";

    dataDir = mkOption {
      default = "/var/cache/llm";
      type = types.str;
      description = "Where to store states to persist";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address on which the default local LLM backend should listen";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port exposed by the default local LLM backend";
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
        "nomic-embed-text" = {
          url = "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q4_K_M.gguf";
          sha256 = "sha256-1OOIiU4JzzgW6LCJbYHSZbVeep//mrA/6L9O9eESlaw=";
        };
      };

      description = "List of llama.cpp GGUF models to pull";
    };

    model = mkOption {
      type =
        types.enum
        (builtins.attrNames config.laplace.services.llm.modelRegistry);

      default = "qwen3";

      description = "Which llama.cpp GGUF model to choose";
    };

    contextSize = mkOption {
      type = types.int;
      default = 4096;
      description = "Context size of llama-cpp";
    };

    vllm = {
      package = mkOption {
        type = types.package;
        default = pkgs.unstable.vllm;
        description = "vLLM package to run; defaults to unstable for current ROCm packaging fixes";
      };

      model = mkOption {
        type = types.str;
        default = "google/gemma-4-26B-A4B-it";
        description = "Hugging Face model ID used when modelSource is unset, and default advertised model name";
      };

      modelSource = mkOption {
        type = types.nullOr (types.enum (builtins.attrNames config.laplace.services.llm.vllm.modelRegistry));
        default = null;
        description = "Optional vLLM modelRegistry key to fetch into the Nix store and serve instead of downloading at runtime";
      };

      modelRegistry = mkOption {
        type = types.attrsOf (types.submodule ({name, ...}: {
          options = {
            url = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Git repository URL for the ${name} HF-format model";
            };

            rev = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Pinned Git revision for the ${name} model repository";
            };

            hash = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Recursive Nix hash for the ${name} model repository";
            };

            fetchLFS = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to fetch Git LFS files for the ${name} model repository";
            };

            files = mkOption {
              type = types.attrsOf (types.submodule ({name, ...}: {
                options = {
                  url = mkOption {
                    type = types.str;
                    description = "Source URL for the ${name} model file";
                  };

                  hash = mkOption {
                    type = types.str;
                    description = "Flat Nix hash for the ${name} model file";
                  };
                };
              }));
              default = {};
              description = "Files to assemble into an HF-format model directory in the Nix store";
            };
          };
        }));
        default = {};
        description = "HF-format vLLM models fetched by Nix instead of vLLM at runtime";
      };

      offline = mkOption {
        type = types.bool;
        default = config.laplace.services.llm.vllm.modelSource != null;
        description = "Whether to force Hugging Face and Transformers offline mode for vLLM";
      };

      servedModelName = mkOption {
        type = types.str;
        default = config.laplace.services.llm.vllm.model;
        description = "Model name advertised by the vLLM OpenAI-compatible API";
      };

      host = mkOption {
        type = types.str;
        default = config.laplace.services.llm.host;
        description = "Address on which vLLM should listen";
      };

      port = mkOption {
        type = types.port;
        default = config.laplace.services.llm.port;
        description = "Port exposed by vLLM";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to open the firewall for the vLLM port";
      };

      maxModelLen = mkOption {
        type = types.int;
        default = 4096;
        description = "Maximum context length served by vLLM";
      };

      gpuMemoryUtilization = mkOption {
        type = types.float;
        default = 0.85;
        description = "Fraction of GPU memory vLLM may use";
      };

      dtype = mkOption {
        type = types.str;
        default = "auto";
        description = "Data type passed to vLLM via --dtype";
      };

      trustRemoteCode = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to pass --trust-remote-code to vLLM";
      };

      rocm = {
        enableCompat = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to set ROCm compatibility variables for consumer AMD GPUs";
        };

        hsaOverrideGfxVersion = mkOption {
          type = types.str;
          default = "10.3.0";
          description = "ROCm GFX version exposed through HSA_OVERRIDE_GFX_VERSION";
        };

        pytorchRocmArch = mkOption {
          type = types.str;
          default = "gfx1030";
          description = "ROCm architecture exposed through PYTORCH_ROCM_ARCH";
        };
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Additional environment variables passed to vLLM";
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Optional environment file with extra vLLM settings or secrets";
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional arguments passed to vLLM serve";
      };
    };

    embedding = {
      enable =
        mkEnableOption
        "Whether or not to run a dedicated llama-cpp embedding server";

      model = mkOption {
        type =
          types.enum
          (builtins.attrNames config.laplace.services.llm.modelRegistry);

        default = defaultEmbeddingModel;

        description = "Which model to use for embeddings";
      };

      contextSize = mkOption {
        type = types.int;
        default =
          if config.laplace.services.llm.embedding.model == "nomic-embed-text"
          then 8192
          else config.laplace.services.llm.contextSize;
        description = "Context size of the embedding llama-cpp server";
      };

      host = mkOption {
        type = types.str;
        default = config.laplace.services.llm.host;
        description = "Address on which the embedding llama-cpp server should listen";
      };

      port = mkOption {
        type = types.port;
        default = 8082;
        description = "Port exposed by the embedding llama-cpp server";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to open the firewall for the embedding llama-cpp port";
      };

      extraFlags = mkOption {
        type = types.listOf types.str;
        default =
          if config.laplace.services.llm.embedding.model == "nomic-embed-text"
          then [
            "--rope-scaling"
            "yarn"
            "--rope-freq-scale"
            ".75"
          ]
          else [];
        example = [
          "--pooling"
          "cls"
          "--ubatch-size"
          "8192"
        ];
        description = "Additional flags passed to the embedding llama-cpp server";
      };
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
                description = "OpenAI-compatible endpoint (e.g., the active local backend)";
              };

              apiKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional API key for the custom endpoint";
              };

              modelName = mkOption {
                type = types.str;
                default = activeModelName;
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
        "Whether or not to enable Open WebUI for the local LLM service";

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
        default = activeOpenAIEndpoint;
        description = "OpenAI-compatible URL Open WebUI should use for the active backend (include `/v1`)";
      };

      apiKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional API key passed to the OpenAI-compatible backend endpoint";
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
