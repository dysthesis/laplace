{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.laplace.security.privesc;
in
{
  config = mkIf (cfg == "sudo") {
    security.sudo.enable = true;
  };
}
