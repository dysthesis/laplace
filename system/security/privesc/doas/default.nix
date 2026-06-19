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
          # keepEnv intentionally omitted: doas already resets PATH, and keeping
          # the caller's env would also retain LD_PRELOAD/LD_* into the root
          # command. Add an explicit `setenv` allowlist here if a specific
          # variable is ever genuinely needed.
        }
      ];
    };
    environment.shellAliases = {
      sudo = "doas";
    };
  };
}
