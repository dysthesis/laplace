{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.laplace.services.radicle = {
    enable = mkEnableOption "Whether or not to enable Radicle Seed";

    dataDir = mkOption {
      default = "/etc/radicle";
      type = types.str;
      description = "Where to store states to persist";
    };
  };
}
