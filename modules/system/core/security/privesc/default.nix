{
  config,
  lib,
  ...
}: let
  inherit (lib.laplace.options) mkEnumOption;
  cfg = config.laplace.security.privesc;
in {
  options.laplace.security.privesc = mkEnumOption {
    elems = [
      "doas"
      "sudo"
    ];
    description = "Which privilege escalation program to use.";
  };

  config = {
    security.doas.enable = cfg == "doas";
    security.sudo.enable = !config.security.doas.enable;
  };
}
