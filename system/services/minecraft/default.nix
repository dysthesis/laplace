{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption optional optionalAttrs optionalString recursiveUpdate types;

  cfg = config.laplace.services.minecraft.retirement-home;
  minecraftMaintenanceLock = "/run/lock/minecraft-maintenance.lock";

  # PackWiz source; loki serves the same tree to clients at /packwiz, so client
  # and server resolve from one manifest.
  packwizSource = builtins.path {
    path = ./retirement-home-packwiz;
    name = "retirement-home-packwiz";
  };

  serverPackage = pkgs.fabricServers.fabric-1_20_1.override {
    loaderVersion = "0.19.2"; # matches the packwiz Fabric loader version
    # Keep Java 17 for mod compatibility; Oracle's public GraalVM 17 is archived.
    jre_headless = pkgs.temurin-bin-17;
  };

  # Discord to Minecraft chat bridge (server-only).
  discordIntegration = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/rbJ7eS5V/versions/WLOprDDs/dcintegration-fabric-3.0.7-1.20.1.jar";
    hash = "sha512-RyPz/8Dv76Y9Scrhglo+w8vO+B3bd5ZfouYdDp17ho6gNydLVI2m9fU7K92eo0qB6scaOp0Hb2qC9u29QhoKvw==";
  };

  # Server-admin mods, server-side only (never in the client zip, so no drift):
  # Ledger = block logging + `/ledger rollback`; squaremap = web map at
  # map.dysthesis.com (needs only fabric-api, already in the pack).
  # Ledger PINNED to 1.2.8, not 1.3.18-backport: 1.3.18 needs fabric-language-kotlin
  # >=1.13.4 but the pack ships 1.10.18, and bumping FLK ripples through every other
  # Kotlin mod (and drifts from the client). 1.2.8 needs only >=1.9.4. If the
  # pack's FLK ever passes 1.13.4, move back to 1.3.18-backport.
  ledger = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/LVN9ygNV/versions/pOxgWfwI/ledger-1.2.8.jar";
    hash = "sha512-gjCufvVJXdQ7brwZ+yErf/sQ3FcfxYbsx+LMgXeYnapBwQKsOG2CWGyDoLSLnbop8JX/pLjXjjTXFeJYMBF/jQ==";
  };
  squaremap = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/PFb7ZqK6/versions/AS12cZm5/squaremap-fabric-mc1.20.1-1.2.0.jar";
    hash = "sha512-4cjgvrjJUtvgoJAtAQIHqwx3SovdOXE2kxaVIIHgO3f7Vm6q2rWRK6MSStMNW5QZfQ2T7Nvdl/hsO/QBDKI97g==";
  };

  # discord-config.nix rendered to TOML (see its header for the @VAR@ secret
  # mechanism), with the mod's example invite URL overridden when one is set.
  discordIntegrationConfig =
    (pkgs.formats.toml {}).generate "Discord-Integration.toml"
    (recursiveUpdate (import ./discord-config.nix)
      (optionalAttrs (cfg.discord.inviteUrl != null) {
        ingameCommand = {
          inviteURL = cfg.discord.inviteUrl;
          message = "Join our Discord! ${cfg.discord.inviteUrl}";
        };
      }));

  # builtins.path gives the config a proper store context; a bare
  # ./squaremap-config.yml in the start-pre file-copy is contextless — nix
  # warns it "will not have a correct store reference".
  squaremapConfig = builtins.path {
    path = ./squaremap-config.yml;
    name = "squaremap-config.yml";
  };

  serverIcon = builtins.path {
    path = ./server-icon.png;
    name = "server-icon.png";
  };

  serverPack =
    (pkgs.fetchPackwizModpack {
      src = packwizSource;
      side = "server";
      packHash = "sha256-CbqAq2RTmZsjHsbUGFuMMkJ8C/6T9vuw7BNz+fNrBMM=";
    }).addFiles ({
        "mods/ledger-1.2.8.jar" = ledger;
        "mods/squaremap-fabric-mc1.20.1-1.2.0.jar" = squaremap;
      }
      // optionalAttrs cfg.discord.enable {
        "mods/dcintegration-fabric-3.0.7-1.20.1.jar" = discordIntegration;
      });
in {
  imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];

  options.laplace.services.minecraft.retirement-home = {
    enable = mkEnableOption "Retirement Home Fabric Minecraft server";

    autoStart = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to start the Retirement Home server on boot.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/srv/minecraft";
      description = "Directory containing Minecraft server state.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the Minecraft server port.";
    };

    port = mkOption {
      type = types.port;
      default = 25565;
      description = "Minecraft server port.";
    };

    maxPlayers = mkOption {
      type = types.ints.positive;
      default = 10;
      description = "Maximum player count.";
    };

    motd = mkOption {
      type = types.str;
      default = "Retirement Home";
      description = "Server MOTD.";
    };

    memoryGb = mkOption {
      type = types.ints.positive;
      default = 8;
      description = ''
        Heap size in GiB allocated to the server. Sets -Xms and -Xmx equal
        (Aikar's rule) to avoid heap-resize GC pauses. 8 GiB suits ~10 players
        on a heavy modpack; modded RAM scales with mods and loaded chunks, not
        player count, so larger values mostly lengthen GC pauses. Keep this
        below the guest's RAM minus ~2 GiB (JVM non-heap + OS + region-file
        page cache) or the heap swaps and every GC faults pages back in.
      '';
    };

    extraJvmOpts = mkOption {
      type = types.str;
      default = "";
      example = "-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+AlwaysPreTouch";
      description = ''
        Extra JVM flags appended after -Xms/-Xmx (GC tuning, JIT, etc.).
        Empty means bare heap flags + the runtime's default G1. The chosen set
        comes from an on-host benchmark (Chunky pregen under fixed load, ranked
        by young-GC pause p99 / GC overhead / throughput); see the tuning plan.
      '';
    };

    restart = mkOption {
      type = types.str;
      default = "no";
      description = "systemd Restart policy for the Retirement Home server.";
    };

    viewDistance = mkOption {
      type = types.ints.positive;
      default = 10;
      description = "Server view distance.";
    };

    simulationDistance = mkOption {
      type = types.ints.positive;
      default = 10;
      description = "Server simulation distance.";
    };

    discord = {
      enable = mkEnableOption "Discord Integration chat bridge mod";

      inviteUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://discord.gg/AbCdEfGh";
        description = ''
          Discord invite link for the in-game /discord command. Unset leaves
          the mod's example placeholder (discord.gg/myserver) in place. Invite
          links are shared with players anyway, so this is not a secret.
        '';
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          systemd EnvironmentFile (source it from sops) providing
          DISCORD_BOT_TOKEN and DISCORD_CHANNEL_ID. nix-minecraft substitutes
          these into config/Discord-Integration.toml (the @VAR@ placeholders) at
          each server start, so the secrets never enter the Nix store. Wired to
          the global services.minecraft-servers.environmentFile, which is fine
          while this host runs a single server.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = optional cfg.discord.enable {
      assertion = cfg.discord.environmentFile != null;
      message = "laplace.services.minecraft.retirement-home.discord.enable needs discord.environmentFile — the sops env file providing DISCORD_BOT_TOKEN and DISCORD_CHANNEL_ID.";
    };

    mnemosyne.dirs = [cfg.dataDir];

    # nix-minecraft substitutes @VAR@ in managed text `files` from this env at
    # ExecStartPre, so the bot token reaches Discord-Integration.toml without
    # ever touching the store. Global option, but loki runs one server.
    services.minecraft-servers.environmentFile = mkIf cfg.discord.enable cfg.discord.environmentFile;

    # Stage service/config changes until a real restart. nix-minecraft's reload
    # deletes managed files while the JVM stays running; enableReload below is
    # retained only to keep its automatic restartIfChanged disabled as well.
    systemd = {
      tmpfiles.rules = ["d /nix/.mc-snapshots 0700 root root -"];
      services = {
        "minecraft-server-retirement-home" = {
          reloadIfChanged = lib.mkForce false;

          # Spark's bundled async-profiler is native C++; expose its only missing
          # runtime dependency without adding a host-wide library search path.
          environment.LD_LIBRARY_PATH =
            lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib];

          # nix-minecraft's hardening omits AF_NETLINK, but glibc getaddrinfo probes
          # interfaces over netlink before resolving — without it every DNS lookup in
          # the JVM throws UnknownHostException, breaking Mojang auth and the Discord
          # bot. Re-add it; the rest of the hardening is untouched.
          serviceConfig.RestrictAddressFamilies =
            lib.mkForce ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
        };

        # World maintenance: 6-hourly btrfs snapshots + nightly restart, both driving
        # the server via nix-minecraft's stdin socket (its own ExecStop idiom).
        # simplification: one host-wide lock serialises all Minecraft maintenance;
        # split it per server if this host ever runs independent instances.
        # Whole-VM PBS->B2 stays the disaster tier; these are the fast rollback tier.

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

                # Hold the validated pipe itself: reopening its pathname in the exit
                # trap could create a regular file if the socket disappears.
                exec 8>"/proc/$main_pid/fd/0"
                saves_disabled=true
                printf '%s\n' 'save-off' >&8
                wait_for_server_log \
                  "$cursor" \
                  '^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\] \[Server thread/INFO\]: (Automatic saving is now disabled|Saving is already turned off)$' \
                  'save-off'

                # The save-off acknowledgement is a command-queue barrier. A new
                # cursor now makes the following completion causal to this flush.
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
                # simplification: fail safely after 60 seconds; raise this ceiling
                # only if measured flush times show that the world needs longer.
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
            # @persist is a btrfs subvol (proxmox profile); snapshot it to a sibling
            # dir on @nix (same filesystem). simplification: snapshots the WHOLE
            # persist subvol, not just the world — cheap CoW; upgrade = carve the world
            # into its own subvol. Ceiling: local only, shares the 64G guest disk with
            # the store; upgrade = `btrfs send` to another host.
            btrfs subvolume snapshot -r /nix/persist "/nix/.mc-snapshots/mc-$(date +%Y%m%d-%H%M%S)"
            restore_saves
            trap - EXIT
            # keep the newest 24 (timestamped names sort chronologically)
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
            # try-restart restarts only if already running, so a deliberate stop stays
            # stopped; ExecStop pipes `stop` to the socket for a clean save.
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

    # Keep Simple Voice Chat exposure tied to the main Minecraft exposure switch.
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
          # Auth/whitelist stay enforced by online-mode + whitelist; this only
          # allows unsigned chat so No Chat Reports can strip reportable proofs.
          enforce-secure-profile = false;
          # Defence-in-depth behind the tailnet `game` ACL. whitelist.json lives
          # at the data-dir root (not the re-copied config/ tree), so console
          # `whitelist add` persists. FOOTGUN: an empty list locks everyone out,
          # ops included — add players from the console (it bypasses the
          # whitelist) right after first deploy.
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
            # Moonlight loads this folder (global_datapacks_folder in
            # moonlight-common.json) as a datapack source. It sits at the PACK
            # root, so the config/ copy above misses it — unmapped, the
            # These packs are required by WooledBoots and VillagersPlus.
            "moonlight-global-datapacks" = "${serverPack}/moonlight-global-datapacks";
            # squaremap reads <datadir>/squaremap/, not config/.
            # The dir already persists; this file is managed only to pin
            # loopback bind, public web-address, and capped render threads
            # (fullrender was dragging TPS).
            "squaremap/config.yml" = squaremapConfig;
          }
          # The config tree is re-copied each start, so the mod's own writes
          # never persist — re-supply the file (token substituted at
          # ExecStartPre) every start instead.
          // optionalAttrs cfg.discord.enable {
            "config/Discord-Integration.toml" = discordIntegrationConfig;
          };
      };
    };
  };
}
