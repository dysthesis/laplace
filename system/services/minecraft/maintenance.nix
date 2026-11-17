# Operational safeguards for the retirement flake's retirement-home instance.
# Do not redeclare its package, mods, Java runtime or server properties here.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.minecraft-servers.servers.retirement-home;
  dataDir = config.services.minecraft-servers.dataDir;
  serverPort = cfg.serverProperties.server-port or 25565;
  minecraftMaintenanceLock = "/run/lock/minecraft-maintenance.lock";
in {
  config = lib.mkIf cfg.enable {
    # Content waits for restart. Do not silently change the live listener.
    # Stop the JVM before a listener change.
    system.preSwitchChecks.minecraftEndpoint = ''
      case "$2" in
        switch|test|dry-activate|check)
          state=$(${config.systemd.package}/bin/systemctl show minecraft-server-retirement-home.service --property=ActiveState --value)
          if [ "$state" != inactive ] && [ "$state" != failed ] &&
             ! ${pkgs.gnugrep}/bin/grep -Fxq ${lib.escapeShellArg "server-port=${toString serverPort}"} ${lib.escapeShellArg "${dataDir}/retirement-home/server.properties"}; then
            echo "Minecraft port change requires maintenance: stop minecraft-server-retirement-home.service, switch, then start it if autoStart is disabled." >&2
            exit 1
          fi
          ;;
      esac
    '';

    # A reload can delete managed files while the JVM runs.
    systemd = {
      tmpfiles.rules = ["d /nix/.mc-snapshots 0700 root root -"];
      services = {
        "minecraft-server-retirement-home" = {
          reloadIfChanged = lib.mkForce false;

          # Limit the native async-profiler dependency to this service.
          environment.LD_LIBRARY_PATH =
            lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib];

          # glibc uses AF_NETLINK before DNS resolution.
          serviceConfig.RestrictAddressFamilies =
            lib.mkForce ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
        };

        # One host lock serialises snapshots and restarts for the single server instance.

        mc-world-snapshot = {
          description = "Quiesce saves + read-only btrfs snapshot of the world";
          path = [pkgs.btrfs-progs pkgs.coreutils pkgs.util-linux];
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "5min";
          };
          script = ''
            exec 9>"${minecraftMaintenanceLock}"
            flock --exclusive 9

            unit=minecraft-server-retirement-home.service
            saves_disabled=false
            restore_saves() {
              if [ "$saves_disabled" = true ]; then
                if ! (trap "" PIPE; printf '%s\n' 'save-on' >&8); then
                  echo "failed to deliver save-on to $unit" >&2
                  return 1
                fi
                saves_disabled=false
              fi
            }
            trap restore_saves EXIT

            journal_cursor() {
              journalctl --lines=0 --show-cursor --quiet --no-pager | sed -n 's/^-- cursor: //p'
            }
            wait_for_server_log() {
              cursor=$1
              pattern=$2
              description=$3
              attempts=0
              until journalctl \
                --unit="$unit" \
                "_SYSTEMD_INVOCATION_ID=$invocation_id" \
                --after-cursor="$cursor" \
                --grep="$pattern" \
                --quiet \
                --no-pager \
                >/dev/null; do
                attempts=$((attempts + 1))
                if [ "$attempts" -ge 60 ]; then
                  echo "$description was not confirmed within 60 seconds; snapshot aborted" >&2
                  return 1
                fi
                sleep 1
              done
            }

            server_state=$(systemctl show --property=ActiveState --value "$unit")
            case "$server_state" in
              active)
                main_pid=$(systemctl show --property=MainPID --value "$unit")
                invocation_id=$(systemctl show --property=InvocationID --value "$unit")
                if [ -z "$invocation_id" ] || [ ! -p "/proc/$main_pid/fd/0" ]; then
                  echo "$unit is active but its invocation or stdin FIFO is unavailable; refusing an unquiesced snapshot" >&2
                  exit 1
                fi

                cursor=$(journal_cursor)
                if [ -z "$cursor" ]; then
                  echo "could not establish a journal cursor before disabling saves" >&2
                  exit 1
                fi

                # Keep the pipe file descriptor open so cleanup cannot recreate the path as a regular file.
                exec 8>"/proc/$main_pid/fd/0"
                saves_disabled=true
                printf '%s\n' 'save-off' >&8
                wait_for_server_log \
                  "$cursor" \
                  '^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\] \[Server thread/INFO\]: (Automatic saving is now disabled|Saving is already turned off)$' \
                  'save-off'

                # The save-off acknowledgement is the queue barrier for this flush.
                cursor=$(journal_cursor)
                if [ -z "$cursor" ]; then
                  echo "could not establish a journal cursor before flushing saves" >&2
                  exit 1
                fi
                marker="laplace:snapshot_$invocation_id-$main_pid-$(date +%s)"
                printf '%s\n%s\n' \
                  'save-all flush' \
                  "data get storage $marker" \
                  >&8
                # Fail after 60 seconds. Increase the limit only if measured flush times are longer.
                wait_for_server_log \
                  "$cursor" \
                  '^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\] \[Server thread/INFO\]: Saved the game$' \
                  'save-all flush'
                wait_for_server_log \
                  "$cursor" \
                  "^\\[[0-9]{2}:[0-9]{2}:[0-9]{2}\\] \\[Server thread/INFO\\]: Storage $marker has the following contents:" \
                  'post-flush command barrier'
                if journalctl \
                  --unit="$unit" \
                  "_SYSTEMD_INVOCATION_ID=$invocation_id" \
                  --after-cursor="$cursor" \
                  --grep='Unable to save the game \(is there enough disk space\?\)$' \
                  --quiet \
                  --no-pager \
                  >/dev/null; then
                  echo "save-all flush reported failure; snapshot aborted" >&2
                  exit 1
                fi
                ;;
              inactive | failed)
                ;;
              *)
                echo "$unit is $server_state; refusing a snapshot during a state transition" >&2
                exit 1
                ;;
            esac

            current_state=$(systemctl show --property=ActiveState --value "$unit")
            if [ "$server_state" = active ]; then
              current_main_pid=$(systemctl show --property=MainPID --value "$unit")
              current_invocation_id=$(systemctl show --property=InvocationID --value "$unit")
              if [ "$current_state" != active ] || [ "$current_main_pid" != "$main_pid" ] || [ "$current_invocation_id" != "$invocation_id" ]; then
                echo "$unit changed invocation after its save barrier; snapshot aborted" >&2
                exit 1
              fi
            elif [ "$current_state" != "$server_state" ]; then
              echo "$unit changed from $server_state to $current_state; snapshot aborted" >&2
              exit 1
            fi
            # The snapshot shares the Btrfs disk with persistent data.
            # Split or send the world subvolume if local disk space is low.
            btrfs subvolume snapshot -r /nix/persist "/nix/.mc-snapshots/mc-$(date +%Y%m%d-%H%M%S)"
            restore_saves
            trap - EXIT
            # Keep the newest 24 snapshots. Timestamp names sort in date order.
            ls -1dr /nix/.mc-snapshots/mc-* 2>/dev/null | tail -n +25 | while read -r snap; do
              btrfs subvolume delete "$snap"
            done
          '';
        };

        mc-nightly-restart = {
          description = "Nightly Minecraft restart (modded memory-leak hygiene)";
          path = [pkgs.coreutils pkgs.util-linux];
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "5min";
          };
          script = ''
            exec 9>"${minecraftMaintenanceLock}"
            flock --exclusive 9

            unit=minecraft-server-retirement-home.service
            main_pid=$(systemctl show --property=MainPID --value "$unit")
            if [ -p "/proc/$main_pid/fd/0" ]; then
              exec 8>"/proc/$main_pid/fd/0"
              printf '%s\n' 'say Nightly restart in 60s' >&8
              sleep 60
            fi
            # try-restart does not start a stopped server. ExecStop saves through stdin.
            systemctl try-restart "$unit"
          '';
        };
      };
      timers = {
        mc-world-snapshot = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-* 00/6:00:00";
            Persistent = true;
          };
        };
        mc-nightly-restart = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "05:00";
            Persistent = true;
          };
        };
      };
    };

  };
}
