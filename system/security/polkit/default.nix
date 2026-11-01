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

    extraConfig = lib.mkIf config.security.polkit.debug ''
      polkit.addRule(function(action, subject) {
        polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
      });
    '';
  };
}
