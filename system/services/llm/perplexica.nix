{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkIf
    mkMerge
    mkDefault
    mkForce
    optionalAttrs
    ;

  root = config.laplace.services.llm;
  cfg = root.search;

  inherit (cfg) dataDir;
  format = pkgs.formats.toml {};

  nonNull = lib.filterAttrs (_: v: v != null);

  models = lib.filterAttrs (_: v: v != {}) {
    OPENAI =
      if cfg.settings.openai == null
      then {}
      else
        nonNull {
          API_KEY = cfg.settings.openai.apiKey;
          ORGANIZATION = cfg.settings.openai.organization;
        };

    CUSTOM_OPENAI =
      if cfg.settings.customOpenAI == null
      then {}
      else
        nonNull {
          API_URL = cfg.settings.customOpenAI.apiUrl;
          API_KEY = cfg.settings.customOpenAI.apiKey;
          MODEL_NAME = cfg.settings.customOpenAI.modelName;
        };

    OLLAMA =
      if cfg.settings.ollama == null
      then {}
      else
        nonNull {
          API_URL = cfg.settings.ollama.apiUrl;
          API_KEY = cfg.settings.ollama.apiKey;
        };
  };

  configToml =
    format.generate "perplexica-config.toml"
    ({
        GENERAL = {
          SIMILARITY_MEASURE = cfg.settings.similarityMeasure;
          KEEP_ALIVE = cfg.settings.keepAlive;
        };

        API_ENDPOINTS = {
          SEARXNG = cfg.settings.searxngUrl;
        };
      }
      // optionalAttrs (models != {}) {MODELS = models;});

  initScript = ''
    install -d -m 750 ${dataDir}/data ${dataDir}/uploads

    if [ ! -f ${dataDir}/config.toml ]; then
      install -D -m 640 ${configToml} ${dataDir}/config.toml
    fi
  '';
in {
  config = mkIf cfg.enable (mkMerge [
    {
      laplace.services.searxng.enable = mkForce true;

      virtualisation = {
        podman.enable = mkDefault true;
        oci-containers.backend = mkDefault "podman";
        oci-containers.containers.perplexica = {
          inherit (cfg) image;
          autoStart = true;
          extraOptions = [
            "--pull=newer"
          ];
          ports = [
            "${cfg.listenAddress}:${toString cfg.port}:3000"
          ];
          environment = {
            SEARXNG_API_URL = cfg.settings.searxngUrl;
          };
          volumes = [
            "${dataDir}/config.toml:/home/perplexica/config.toml"
            "${dataDir}/data:/home/perplexica/data"
            "${dataDir}/uploads:/home/perplexica/uploads"
          ];
        };
      };

      systemd.services.perplexica-init = {
        description = "Initialise Perplexica data";
        wantedBy = ["podman-perplexica.service"];
        before = ["podman-perplexica.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = initScript;
      };

      systemd.services."podman-perplexica" = {
        requires = ["perplexica-init.service"];
        after = ["perplexica-init.service"];
      };
    }
    (mkIf cfg.openFirewall {
      networking.firewall.allowedTCPPorts = [cfg.port];
    })
  ]);
}
