{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.security.privesc;
in {
  config = mkIf (cfg == "doas") {
    security.doas = {
      enable = true;
      extraRules = [
        {
          groups = ["wheel"];
          persist = true;
          keepEnv = true;
        }
      ];
    };
    environment.shellAliases = {
      sudo = "doas";
    };
  };
}
