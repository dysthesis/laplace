{ lib, ... }:
let
  inherit (lib) mkEnableOption types mkOption;
in
{
  options.laplace.services.ollama = {
    enable = mkEnableOption "Whether or not to enable OLLaMa";
    dataDir = mkOption {
      default = "/var/cache/vllm";
      type = types.str;
      description = "Where to store states to persist";
    };
  };
}
