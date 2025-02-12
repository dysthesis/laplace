{lib, ...}: let
  inherit (lib) mkEnableOption mkOption;
  inherit (lib.types) str;
in {
  options.laplace.impermanence = {
    enable = mkEnableOption "Whether or not to enable impermanence";
    persistDir = mkOption {
      default = "/nix/persist";
      type = str;
      description = "Where to store states to persist";
    };
  };
}
