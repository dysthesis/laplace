{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  inherit (config.laplace.hardware) gpu;
in
{
  config = mkIf config.laplace.services.ollama.enable {
    services = {
      open-webui = {
        enable = true;
      };
      ollama = {
        enable = true;
        package = pkgs.unstable.ollama-rocm;
        acceleration =
          if (elem "amd" gpu) then
            "rocm"
          else if (elem "nvidia" gpu) then
            "cuda"
          else
            null;
        environmentVariables = {
          HCC_AMDGPU_TARGET = "gfx1030"; # used to be necessary, but doesn't seem to anymore
          ENABLE_WEB_SEARCH = "True";
          WEB_SEARCH_ENGINE = "searxng";
          WEB_SEARCH_RESULT_COUNT = "20";
          WEB_SEARCH_CONCURRENT_REQUESTS = "20";
          SEARXNG_QUERY_URL = "http://localhost:8100/search?q=<query>";
        };
        # results in environment variable "HSA_OVERRIDE_GFX_VERSION=10.3.0"
        rocmOverrideGfx = "10.3.0";
      };
    };
  };
}
