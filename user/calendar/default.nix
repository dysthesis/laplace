{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkIf getExe elem;
  # phobos and chaos have no age key for /run/secrets/caldav.
  # Disable their sync units to prevent failures on each timer tick. See system/secrets.
  hostName = config.networking.hostName or "";
  enabled =
    elem "demiurge" config.laplace.users
    && elem "desktop" config.laplace.profiles
    && !(elem hostName ["phobos" "chaos"]);

  # discover finds new remote calendars on each sync.
  # `yes |` accepts the "create collection?" prompt when there is no local status directory.
  sync = pkgs.writeShellScript "khal-sync" ''
    ${pkgs.coreutils}/bin/yes | ${getExe pkgs.configured.vdirsyncer} discover
    exec ${getExe pkgs.configured.vdirsyncer} sync
  '';
in {
  config = mkIf enabled {
    systemd.user.services.vdirsyncer = {
      description = "Mirror Radicale (cal.dysthesis.com) into the local vdir";
      # The network and /run/secrets/caldav must be available before sync.
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${sync}";
      };
    };

    systemd.user.timers.vdirsyncer = {
      description = "Periodic calendar sync";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnStartupSec = "2m";
        OnUnitActiveSec = "15m";
        Persistent = true;
      };
    };
  };
}
