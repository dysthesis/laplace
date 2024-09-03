{lib, ...}: let
  inherit (lib) mkOption mkEnableOption;
  inherit (lib.types) string;
in {
  options.laplace.features.nh = {
    enable = mkEnableOption "Whether or not to enable nh";
    flakePath = mkOption {
      type = string;
      description = "Path to the flake with the NixOS configuration";
    };
  };
}
