{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.laplace.security.privesc;
in {
  config = mkIf (cfg == "doas") {
    security.doas = {
      enable = mkForce true;
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
