{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatStringsSep mkEnableOption mkIf mkOption optional optionalAttrs optionalString types;

  cfg = config.laplace.services.minecraft.retirement-home;

  # PrismLauncher instance export; the same file players download from loki's
  # https://mc.dysthesis.com/modpack, so client and server can never drift.
  modpackZip = builtins.path {
    path = ./RetirementHome.zip;
    name = "RetirementHome.zip";
  };

  serverPackage = pkgs.fabricServers.fabric-1_20_1.override {
    loaderVersion = "0.18.4"; # matches the pack's mmc-pack.json
    # Keep Java 17 for Minecraft 1.20.1/mod compatibility; CE is currently Java 25.
    jre_headless = pkgs.graalvmPackages.graalvm-oracle_17;
  };

  # Discord to Minecraft chat bridge (server-only).
  discordIntegration = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/rbJ7eS5V/versions/WLOprDDs/dcintegration-fabric-3.0.7-1.20.1.jar";
    hash = "sha512-RyPz/8Dv76Y9Scrhglo+w8vO+B3bd5ZfouYdDp17ho6gNydLVI2m9fU7K92eo0qB6scaOp0Hb2qC9u29QhoKvw==";
  };

  # Server-admin mods, server-side only (never in the client zip, so no drift):
  # Ledger = block logging + `/ledger rollback`; squaremap = server-rendered web
  # map served at map.dysthesis.com. squaremap needs only fabric-api (in the pack).
  # Ledger is PINNED to 1.2.8, NOT the newest 1.3.18-backport: 1.3.18 hard-requires
  # fabric-language-kotlin >=1.13.4+kotlin.2.2.0, but the pack ships FLK 1.10.18 and
  # bumping it would ripple through every other Kotlin mod (and drift from the
  # client). 1.2.8 requires only FLK >=1.9.4, which the pack's 1.10.18 satisfies;
  # its `breaks: cardboard` is moot (Cardboard isn't installed). If the pack's FLK
  # is ever bumped past 1.13.4, move back to 1.3.18-backport. Hashes from:
  #   nix store prefetch-file --hash-type sha512 <url>
  ledger = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/LVN9ygNV/versions/pOxgWfwI/ledger-1.2.8.jar";
    hash = "sha512-gjCufvVJXdQ7brwZ+yErf/sQ3FcfxYbsx+LMgXeYnapBwQKsOG2CWGyDoLSLnbop8JX/pLjXjjTXFeJYMBF/jQ==";
  };
  squaremap = pkgs.fetchurl {
    url = "https://cdn.modrinth.com/data/PFb7ZqK6/versions/AS12cZm5/squaremap-fabric-mc1.20.1-1.2.0.jar";
    hash = "sha512-4cjgvrjJUtvgoJAtAQIHqwx3SovdOXE2kxaVIIHgO3f7Vm6q2rWRK6MSStMNW5QZfQ2T7Nvdl/hsO/QBDKI97g==";
  };

  # The mod config as Nix data (discord-config.nix), rendered to
  # config/Discord-Integration.toml. botToken/botChannel stay @VAR@ placeholders
  # substituted at server start from the env file by nix-minecraft.
  discordIntegrationConfig =
    (pkgs.formats.toml {}).generate "Discord-Integration.toml" (import ./discord-config.nix);

  # Bring the sparse squaremap config into the store as its own path (with proper
  # context), the same idiom as modpackZip above. A bare `./squaremap-config.yml`
  # reference in the start-pre file-copy is otherwise a contextless flake-source
  # path — nix warns it "will not have a correct store reference".
  squaremapConfig = builtins.path {
    path = ./squaremap-config.yml;
    name = "squaremap-config.yml";
  };

  # Jars added to the Prism instance by hand carry no .index metadata, so the
  # side filter below can't classify them; these are the client-only ones.
  # Also the dumping ground for mods whose `side = 'both'` label lies (the
  # Homestead lesson): a mod that crashes headless startup gets appended here.
  serverExcludedMods = [
    "ImmediatelyFast-Fabric-1.5.5+1.20.4.jar"
    "holdthatchunk-2.0.1.jar"
    "indium-1.0.36+mc1.20.1.jar"
    "iris-1.7.6+mc1.20.1.jar"
    "reeses_sodium_options-1.7.2+mc1.20.1-build.101.jar"
    "sodium-extra-0.5.9+mc1.20.1.jar"
    "sodium-fabric-0.5.13+mc1.20.1.jar"
  ];

  serverExcludedModNames = pkgs.writeText "retirement-home-excluded-mods" (concatStringsSep "\n" serverExcludedMods);

  # The side labels lie the other way too: marked client-only in .index, but
  # server mods hard-depend on them. Fusion is Rechiseled's textures API —
  # `environment: "*"` in its fabric.mod.json, Fabric refuses to resolve the
  # server without it.
  serverIncludedMods = [
    "fusion-1.3.5-fabric-mc1.20.1.jar"
  ];

  serverIncludedModNames = pkgs.writeText "retirement-home-included-mods" (concatStringsSep "\n" serverIncludedMods);

  # Server subset of the pack: config/ plus every mod not marked client-only.
  # Prism writes packwiz-style .index/*.pw.toml metadata (with a `side` field)
  # for each mod installed through its downloader; hand-added jars have no
  # metadata and fall through to the exclusion list above.
  serverPack = pkgs.runCommandLocal "retirement-home-server-pack" {
    nativeBuildInputs = [pkgs.unzip];
  } ''
    unzip -q ${modpackZip} 'minecraft/config/*' 'minecraft/mods/*'
    mkdir -p "$out/mods"
    cp -r minecraft/config "$out/config"
    cd minecraft/mods
    for jar in *.jar; do
      if grep -Fxq "$jar" ${serverExcludedModNames}; then
        continue
      fi
      if ! grep -Fxq "$jar" ${serverIncludedModNames}; then
        toml=$(grep -Flx "filename = '$jar'" .index/*.pw.toml || true)
        if [ -n "$toml" ] && grep -Fq "side = 'client'" $toml; then
          continue
        fi
      fi
      cp "$jar" "$out/mods/$jar"
    done
    ${optionalString cfg.discord.enable ''
      cp ${discordIntegration} "$out/mods/dcintegration-fabric-3.0.7-1.20.1.jar"
    ''}
    cp ${ledger} "$out/mods/ledger-1.2.8.jar"
    cp ${squaremap} "$out/mods/squaremap-fabric-mc1.20.1-1.2.0.jar"
  '';
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

    # nix-minecraft's unit hardening sets RestrictAddressFamilies without
    # AF_NETLINK. glibc getaddrinfo probes interfaces over a netlink socket
    # before resolving, so without it every outbound DNS lookup in the sandboxed
    # JVM throws UnknownHostException — breaking both Mojang online-mode auth and
    # the Discord bot's login. Add AF_NETLINK back; the rest of the hardening
    # (no caps, PrivateDevices, etc.) is untouched.
    systemd.services."minecraft-server-retirement-home".serviceConfig.RestrictAddressFamilies =
      lib.mkForce ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];

    # --- World maintenance: 6-hourly btrfs snapshots + a nightly restart. ---
    # Both drive the server over nix-minecraft's stdin socket (default runDir
    # /run/minecraft + the "retirement-home" server name), mirroring the module's
    # own ExecStop `echo stop > …stdin` idiom. Whole-VM PBS->B2 stays the coarse
    # disaster-recovery tier; these snapshots are the fast in-guest rollback tier.
    systemd.tmpfiles.rules = ["d /nix/.mc-snapshots 0700 root root -"];

    systemd.services.mc-world-snapshot = {
      description = "Quiesce saves + read-only btrfs snapshot of the world";
      path = [pkgs.btrfs-progs pkgs.coreutils];
      serviceConfig.Type = "oneshot";
      script = ''
        sock=/run/minecraft/retirement-home.stdin
        if [ -e "$sock" ]; then
          echo 'save-off'       > "$sock"
          echo 'save-all flush' > "$sock"
          sleep 10 # simplification: fixed flush wait; ceiling = very large worlds; upgrade = poll the journal for "Saved the game"
        fi
        # @persist is a btrfs subvol (proxmox profile); snapshot it to a sibling
        # dir on @nix (same filesystem). simplification: snapshots the WHOLE
        # persist subvol, not just the world — cheap CoW; upgrade = carve the world
        # into its own subvol. Ceiling: local only, shares the 64G guest disk with
        # the store; upgrade = `btrfs send` to another host.
        btrfs subvolume snapshot -r /nix/persist "/nix/.mc-snapshots/mc-$(date +%Y%m%d-%H%M%S)"
        [ -e "$sock" ] && echo 'save-on' > "$sock"
        # keep the newest 24 (timestamped names sort chronologically)
        ls -1dr /nix/.mc-snapshots/mc-* 2>/dev/null | tail -n +25 | while read -r snap; do
          btrfs subvolume delete "$snap"
        done
      '';
    };
    systemd.timers.mc-world-snapshot = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-* 00/6:00:00";
        Persistent = true;
      };
    };

    systemd.services.mc-nightly-restart = {
      description = "Nightly Minecraft restart (modded memory-leak hygiene)";
      path = [pkgs.coreutils];
      serviceConfig.Type = "oneshot";
      script = ''
        sock=/run/minecraft/retirement-home.stdin
        [ -e "$sock" ] && { echo 'say Nightly restart in 60s' > "$sock"; sleep 60; }
        # try-restart restarts only if already running, so a deliberate stop stays
        # stopped; ExecStop pipes `stop` to the socket for a clean save.
        systemctl try-restart minecraft-server-retirement-home.service
      '';
    };
    systemd.timers.mc-nightly-restart = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "05:00";
        Persistent = true;
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
          # Defence-in-depth behind the tailnet `game` ACL: only accounts in
          # whitelist.json may join, and enforce-whitelist also kicks any
          # non-listed player still online on a /reload. whitelist.json lives at
          # the data-dir root (NOT under the re-copied config/ tree), so
          # `whitelist add <ign>` from the console persists across restarts.
          # NOTE: enabling this with an empty list locks EVERYONE out (ops
          # included) until you add them — run the adds from the console right
          # after the first deploy; the console bypasses the whitelist.
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
            # squaremap keeps its config in its OWN data dir (<datadir>/squaremap/),
            # NOT the Fabric config/ dir — a config/squaremap/config.yml is silently
            # ignored (that mistake shipped once). That dir sits outside the config/
            # tree re-copied each start, so it (and tiles) already persist; we manage
            # this file only to pin overrides: loopback bind, public web-address, and
            # capped render threads so a fullrender stops dragging TPS. See
            # squaremap-config.yml.
            "squaremap/config.yml" = squaremapConfig;
          }
          # Keyed after "config" so it lands in the dir copy, not under it: the
          # whole config tree is re-copied each start, so the mod's own writes to
          # this file never persist — we re-supply it (token substituted from
          # environmentFile at ExecStartPre) every start instead.
          // optionalAttrs cfg.discord.enable {
            "config/Discord-Integration.toml" = discordIntegrationConfig;
          };
      };
    };
  };
}
