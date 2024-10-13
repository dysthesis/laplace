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
      settings = {
        service = {
          enableregistration = false;
          enablecaldav = true;
          timezone = "Australia/Sydney";
          defaultsettings = {
            avatar_provider = "gravatar";
            week_start = 1; # monday
          };
        };
      };
    };
    users = {
      groups.vikunja = {};

      users."vikunja" = {
        group = "vikunja";
        createHome = false;
        isSystemUser = true;
      };
    };
  };
}
