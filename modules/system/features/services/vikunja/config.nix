{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.vikunja;
in {
  config = mkIf cfg.enable {
    services.vikunja = {
      enable = true;
      frontendScheme = "https";
      frontendHostname = "todo.dysthesis.com";
    };
  };
}
