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

  # The mod config as Nix data (discord-config.nix), rendered to
  # config/Discord-Integration.toml. botToken/botChannel stay @VAR@ placeholders
  # substituted at server start from the env file by nix-minecraft.
  discordIntegrationConfig =
    (pkgs.formats.toml {}).generate "Discord-Integration.toml" (import ./discord-config.nix);

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
        player count, so larger values mostly lengthen GC pauses.
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
        jvmOpts = "-Xms${toString cfg.memoryGb}G -Xmx${toString cfg.memoryGb}G";
        inherit (cfg) autoStart restart;

        serverProperties = {
          server-port = cfg.port;
          max-players = cfg.maxPlayers;
          inherit (cfg) motd;
          view-distance = cfg.viewDistance;
          simulation-distance = cfg.simulationDistance;
          online-mode = true;
          enable-rcon = false;
          level-seed = "599696504823152026";
          difficulty = 3;
          spawn-protection = 1;
        };

        symlinks.mods = "${serverPack}/mods";

        files =
          {
            config = "${serverPack}/config";
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
