{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkIf
    optionalAttrs
    ;

  root = config.laplace.services.llm;
  cfg = root.webui;

  environment =
    {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
      ENABLE_OPENAI_API = "True";
      ENABLE_OLLAMA_API =
        if cfg.enableOllama
        then "True"
        else "False";
      OPENAI_API_BASE_URLS = cfg.apiUrl;
    }
    // optionalAttrs (cfg.apiKey != null) {
      OPENAI_API_KEYS = cfg.apiKey;
    }
    // optionalAttrs (cfg.modelListTimeout != null) {
      AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST = toString cfg.modelListTimeout;
    }
    // cfg.environment;
in {
  config = mkIf cfg.enable {
    services.open-webui = {
      enable = true;
      inherit
        (cfg)
        environmentFile
        host
        openFirewall
        port
        stateDir
        ;
      inherit environment;
    };

    systemd.services.open-webui = mkIf root.enable {
      wants = ["llama-cpp.service"];
      after = ["llama-cpp.service"];
    };
  };
}
