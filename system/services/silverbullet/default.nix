{
  config,
  lib,
  ...
}: let
  cfg = config.laplace.services.silverbullet.enable;
  inherit (lib) mkEnableOption mkIf;
  port = 8101;
in {
  options.laplace.services.silverbullet.enable =
    mkEnableOption "SilverBullet, a self-hosted Personal Knowledge Management web app";

  config = mkIf cfg {
    # spaceDir defaults to /var/lib/silverbullet (a StateDirectory); persist it.
    mnemosyne.dirs = ["/var/lib/silverbullet"];

    services.silverbullet = {
      enable = true;
      listenAddress = "127.0.0.1";
      listenPort = port;
    };
  };
}
