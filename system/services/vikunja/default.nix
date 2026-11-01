{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.services.vikunja;
  inherit (lib) mkEnableOption mkIf;
in {
  options.laplace.services.vikunja =
    {enable = mkEnableOption "Vikunja, a self-hosted to-do / task management web app";}
    // import ./settings.nix {inherit lib;};

  config = mkIf cfg.enable {
    mnemosyne.dirs = ["/var/lib/private/vikunja"];

    services.vikunja = {
      enable = true;
      # The local Caddy instance serves the loopback API and public frontend.
      address = cfg.listenAddress;
      inherit (cfg) port;
      frontendScheme = lib.mkDefault "http";
      frontendHostname = lib.mkDefault "localhost";
    };
  };
}
