{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  inherit (builtins) elem;
  inherit (config.laplace.hardware) gpu;
in {
  config = mkIf config.laplace.services.ollama.enable {
    services = {
      open-webui = {
        enable = true;
        package = pkgs.unstable.open-webui;
      };
      ollama = {
        enable = true;
        package = pkgs.unstable.ollama-rocm;
        acceleration =
          if (elem "amd" gpu)
          then "rocm"
          else if (elem "nvidia" gpu)
          then "cuda"
          else null;
        environmentVariables = {
          HCC_AMDGPU_TARGET = "gfx1032"; # used to be necessary, but doesn't seem to anymore
          OLLAMA_CONTEXT_LENGTH = "2048";
          OLLAMA_FLASH_ATTENTION = "1";
        };
        # results in environment variable "HSA_OVERRIDE_GFX_VERSION=10.3.0"
        rocmOverrideGfx = "10.3.2";
      };
    };
  };
}
