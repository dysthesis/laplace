{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf optional optionalAttrs optionalString recursiveUpdate;

  cfg = config.laplace.services.minecraft.retirement-home;
  minecraftMaintenanceLock = "/run/lock/minecraft-maintenance.lock";

  # The server and clients share this PackWiz manifest.
  packwizSource = builtins.path {
    path = ./packwiz;
    name = "retirement-home-packwiz";
  };

  serverPackage = pkgs.fabricServers.fabric-1_20_1.override {
    loaderVersion = "0.19.2"; # Match the PackWiz Fabric loader version.
    # Keep Java 17 for mod compatibility.
    jre_headless = pkgs.temurin-bin-17;
  };

  discordIntegration = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/rbJ7eS5V/versions/WLOprDDs/dcintegration-fabric-3.0.7-1.20.1.jar";
    hash = "sha512-RyPz/8Dv76Y9Scrhglo+w8vO+B3bd5ZfouYdDp17ho6gNydLVI2m9fU7K92eo0qB6scaOp0Hb2qC9u29QhoKvw==";
  };

  # Ledger 1.2.8 matches the bundled Kotlin runtime.
  # Upgrade Ledger only after fabric-language-kotlin reaches 1.13.4.
  ledger = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/LVN9ygNV/versions/pOxgWfwI/ledger-1.2.8.jar";
    hash = "sha512-gjCufvVJXdQ7brwZ+yErf/sQ3FcfxYbsx+LMgXeYnapBwQKsOG2CWGyDoLSLnbop8JX/pLjXjjTXFeJYMBF/jQ==";
  };
  squaremap = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/PFb7ZqK6/versions/AS12cZm5/squaremap-fabric-mc1.20.1-1.2.0.jar";
    hash = "sha512-4cjgvrjJUtvgoJAtAQIHqwx3SovdOXE2kxaVIIHgO3f7Vm6q2rWRK6MSStMNW5QZfQ2T7Nvdl/hsO/QBDKI97g==";
  };

  discordIntegrationConfig =
    (pkgs.formats.toml {}).generate "Discord-Integration.toml"
    (recursiveUpdate (import ./discord-config.nix)
      (optionalAttrs (cfg.discord.inviteUrl != null) {
        ingameCommand = {
          inviteURL = cfg.discord.inviteUrl;
          message = "Join our Discord! ${cfg.discord.inviteUrl}";
        };
      }));

  squaremapConfig =
    pkgs.writeText "squaremap-config.yml"
    (lib.replaceStrings ["@MAP_ORIGIN@"] ["https://${cfg.mapDomain}"] (builtins.readFile ./squaremap-config.yml));

  serverIcon = builtins.path {
    path = ./server-icon.png;
    name = "server-icon.png";
  };

  serverPack =
    (pkgs.fetchPackwizModpack {
      src = packwizSource;
      side = "server";
      packHash = "sha256-W0qo9zuvmWEoBsS+jROpkJXdYZ6msYd4UoemCcH0b34=";
    }).addFiles ({
        "mods/ledger-1.2.8.jar" = ledger;
        "mods/squaremap-fabric-mc1.20.1-1.2.0.jar" = squaremap;
      }
      // optionalAttrs cfg.discord.enable {
        "mods/dcintegration-fabric-3.0.7-1.20.1.jar" = discordIntegration;
      });
in {
  imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];

  options.laplace.services.minecraft.retirement-home =
    {
      enable = mkEnableOption "Retirement Home Fabric Minecraft server";
    }
    // import ./options.nix {inherit lib;};

  config = mkIf cfg.enable {
    assertions = optional cfg.discord.enable {
      assertion = cfg.discord.environmentFile != null;
      message = "laplace.services.minecraft.retirement-home.discord.enable needs discord.environmentFile — the sops env file providing DISCORD_BOT_TOKEN and DISCORD_CHANNEL_ID.";
    };

    mnemosyne.dirs = [cfg.dataDir];

    # Content waits for restart. Firewall rules and client artefacts change immediately.
    # Stop the JVM before a listener change.
    system.preSwitchChecks.minecraftEndpoint = ''
      case "$2" in
        switch|test|dry-activate|check)
          state=$(${config.systemd.package}/bin/systemctl show minecraft-server-retirement-home.service --property=ActiveState --value)
          if [ "$state" != inactive ] && [ "$state" != failed ] &&
             ! ${pkgs.gnugrep}/bin/grep -Fxq ${lib.escapeShellArg "server-port=${toString cfg.port}"} ${lib.escapeShellArg "${cfg.dataDir}/retirement-home/server.properties"}; then
            echo "Minecraft port change requires maintenance: stop minecraft-server-retirement-home.service, switch, then start it if autoStart is disabled." >&2
            exit 1
          fi
          ;;
      esac
    '';

    # Substitute Discord secrets at startup. Keep them outside the store.
    services.minecraft-servers.environmentFile = mkIf cfg.discord.enable cfg.discord.environmentFile;

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

        # Serialise snapshots and clean restarts through the server stdin socket.
        # One host lock serialises maintenance for the single server instance.

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

    # Use the Minecraft firewall switch for Simple Voice Chat.
    # See: https://modrepo.de/minecraft/voicechat/wiki/server_setup_self_hosted
    networking.firewall.allowedUDPPorts = optional cfg.openFirewall 24454;

    services.minecraft-servers = {
      enable = true;
      eula = true;
      inherit (cfg) dataDir openFirewall;

      managementSystem = {
        tmux.enable = false;
        systemd-socket.enable = true;
      };

      servers.retirement-home = {
        enable = true;
        enableReload = true;
        package = serverPackage;
        jvmOpts = "-Xms${toString cfg.memoryGb}G -Xmx${toString cfg.memoryGb}G${optionalString (cfg.extraJvmOpts != "") " ${cfg.extraJvmOpts}"}";
        inherit (cfg) autoStart restart;

        serverProperties = {
          server-port = cfg.port;
          max-players = cfg.maxPlayers;
          inherit (cfg) motd;
          view-distance = cfg.viewDistance;
          simulation-distance = cfg.simulationDistance;
          online-mode = true;
          # Keep online authentication and the whitelist. Let No Chat Reports use unsigned chat.
          # whitelist.json persists at the data root. An empty list prevents all player access.
          white-list = true;
          enforce-whitelist = true;
          enable-rcon = false;
          level-seed = "599696504823152026";
          difficulty = 3;
          spawn-protection = 1;
        };

        symlinks.mods = "${serverPack}/mods";

        files =
          {
            config = "${serverPack}/config";
            "server-icon.png" = serverIcon;
            # Moonlight loads the necessary datapacks from the pack root, not config/.
            "moonlight-global-datapacks" = "${serverPack}/moonlight-global-datapacks";
            # squaremap reads its data directory. Set its bind address and render limits.
            "squaremap/config.yml" = squaremapConfig;
          }
          # Recreate the runtime-secret configuration after each configuration tree reset.
          // optionalAttrs cfg.discord.enable {
            "config/Discord-Integration.toml" = discordIntegrationConfig;
          };
      };
    };
  };
}
