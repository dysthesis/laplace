{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.laplace.features.services.owntracks;
in {
  config = mkIf cfg.enable {
    systemd.services.owntracks = {
      enable = true;

      description = "Owntracks";
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${pkgs.owntracks-recorder}/bin/ot-recorder -S /var/lib/owntracks --doc-root ${pkgs.owntracks-recorder}/docroot --port 0 --http-host 127.0.0.1 --http-port ${toString cfg.port}";
        StateDirectory = "owntracks";
        DynamicUser = true;

        Restart = "on-failure";
        KillSignal = "SIGINT";
      };
    };
  };
}
