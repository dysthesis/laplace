{lib, ...}: let
  inherit
    (lib)
    mkEnableOption
    mkOption
    types
    ;
in {
  options.laplace.services.forgejo = {
    enable = mkEnableOption "Whether or not to enable Forgejo";
    stateDir = mkOption {
      type = types.path;
      default = "/var/lib/forgejo";
      description = "Where Forgejo stores state data";
    };
  };
}
