{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption;
  inherit (lib.types) str;
in
{
  options.laplace.nh = {
    enable = mkEnableOption "Whether or not to enable nh";
    flakePath = mkOption {
      type = str;
      description = "Path to the flake with the NixOS configuration";
    };
  };
}
