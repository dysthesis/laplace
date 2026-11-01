{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.services.silverbullet;
  inherit (lib) mkEnableOption mkIf;
in {
  options.laplace.services.silverbullet =
    {enable = mkEnableOption "SilverBullet, a self-hosted Personal Knowledge Management web app";}
    // import ./settings.nix {inherit lib;};

  config = mkIf cfg.enable {
    # Persist the default spaceDir StateDirectory at /var/lib/silverbullet.
    mnemosyne.dirs = ["/var/lib/silverbullet"];

    services.silverbullet = {
      enable = true;
      inherit (cfg) listenAddress;
      listenPort = cfg.port;
    };
  };
}
