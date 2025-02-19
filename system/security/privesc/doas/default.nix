{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.laplace.security.privesc;
in {
  config = mkIf (cfg == "doas") {
    security.sudo.enable = mkForce false;
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
