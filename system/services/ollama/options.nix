{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.services.ollama.enable = mkEnableOption "Whether or not to enable OLLaMa";
}
