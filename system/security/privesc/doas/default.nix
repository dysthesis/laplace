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
          # persist caches the auth timestamp for the session (convenience).
          persist = true;
          # Omit keepEnv to block caller-controlled LD_*; allow variables explicitly.
        }
      ];
    };
    environment.shellAliases = {
      sudo = "doas";
    };
  };
}
