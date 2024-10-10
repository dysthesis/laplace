{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  options.laplace.features.services.excalidraw.enable = mkEnableOption "Whether or not to enable Excalidraw";
}
