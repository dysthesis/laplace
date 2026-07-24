{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkEnableOption;
  cfg = config.laplace.security.polkit;
in {
  options.laplace.security.polkit = {
    enable = mkEnableOption "Whether or not to enable Polkit";
    debug = mkEnableOption "Polkit authorization-check debug logging (verbose; logs every action to the journal)";
  };
  config.security.polkit = {
    enable = mkDefault cfg.enable;
    debug = mkDefault cfg.debug;

    # the below configuration depends on security.polkit.debug being set to true
    # so we have it written only if debugging is enabled
    extraConfig = lib.mkIf config.security.polkit.debug ''
      /* Log authorization checks. */
      polkit.addRule(function(action, subject) {
        polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
      });
    '';
  };
}
