{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.security.polkit.enable;
in {
  security.polkit = {
    # stolen from https://github.com/NotAShelf/nyx/blob/319b1f6fe4d09ff84d83d1f8fa0d04e0220dfed7/modules/core/common/system/security/polkit.nix

    enable = cfg;
    debug = lib.mkDefault cfg;

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
