{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkIf getExe elem;
  # phobos/chaos have no age key, so /run/secrets/khal_caldav never exists there
  # (see system/secrets); skip the sync unit rather than let it fail every tick.
  hostName = config.networking.hostName or "";
  enabled =
    elem "demiurge" config.laplace.users
    && elem "desktop" config.laplace.profiles
    && !(elem hostName ["phobos" "chaos"]);

  # `yes |` auto-confirms vdirsyncer's "create collection?" prompt on the first
  # run (empty local side); it's a no-op once the status dir exists. discover is
  # cheap and keeps new remote calendars picked up without manual intervention.
  sync = pkgs.writeShellScript "khal-sync" ''
    ${pkgs.coreutils}/bin/yes | ${getExe pkgs.configured.vdirsyncer} discover
    exec ${getExe pkgs.configured.vdirsyncer} sync
  '';
in {
  config = mkIf enabled {
    systemd.user.services.vdirsyncer = {
      description = "Mirror Radicale (cal.dysthesis.com) into the local vdir";
      # Network + the sops secret (/run/secrets/khal_caldav) must be up first.
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
