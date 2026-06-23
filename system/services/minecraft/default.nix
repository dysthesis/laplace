{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption optional optionalAttrs optionalString types;

  cfg = config.laplace.services.minecraft.retirement-home;

  modpack = pkgs.fetchModrinthModpack {
    pname = "homestead-modpack";
    version = "1.3.7";
    url = "https://cdn.modrinth.com/data/6HvKwSky/versions/WMsE2fOj/Homestead%201.3.7.mrpack";
    packHash = "sha256-JeT5l11PqP5Hv4HvN2wa4S73I2VRdVGVN9pjJrhwpc0=";
    side = "server";
  };

  serverPackage = pkgs.fabricServers.fabric-1_20_1.override {
    loaderVersion = "0.18.4";
    jre_headless = pkgs.jdk17_headless;
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

  # Homestead's Modrinth manifest marks client-only jars as server-compatible.
  # Exclude them from the server mods directory; Colorwheel also hard-depends
  # Iris and crashes headless server startup.
  serverExcludedMods = [
    "AdvancementPlaques-1.20.1-fabric-1.6.7.jar"
    "AmbientSounds_FABRIC_v6.3.8_mc1.20.1.jar"
    "BHMenu-Fabric-1.20.1-2.4.2.jar"
    "Boat-Item-View-Fabric-1.20.1-0.0.5.jar"
    "DetailArmorBar-2.6.3+1.20.1-fabric.jar"
    "EnchantmentDescriptions-Fabric-1.20.1-17.1.21.jar"
    "EuphoriaPatcher-1.8.6-r5.7.1-fabric.jar"
    "GeckoLibIrisCompat-Fabric-1.0.0.jar"
    "ImmediatelyFast-Fabric-1.5.4+1.20.4.jar"
    "MouseTweaks-fabric-mc1.20-2.26.jar"
    "PresenceFootsteps-1.10.1+1.20.1.jar"
    "Prism-1.20.1-fabric-1.0.5.jar"
    "Searchables-fabric-1.20.1-1.0.3.jar"
    "SignCopy-Fabric-1.20.1-1.1.1.jar"
    "Stfu-1.2.3.jar"
    "TravelersTitles-1.20-Fabric-4.0.2.jar"
    "advancementinfo-1.20-fabric0.83.0-1.4.jar"
    "bettermounthud-1.2.2.jar"
    "chat_heads-0.15.1-fabric-1.20.jar"
    "citresewn-1.2.2+1.20.1.jar"
    "colorwheel_patcher-fabric-1.0.5+mc1.20.1.jar"
    "colorwheel-fabric-1.2.6+mc1.20.1.jar"
    "continuity-3.0.0+1.20.1.jar"
    "cwb-fabric-3.0.0+mc1.20.jar"
    "eating-animation-1.20+1.9.61.jar"
    "enhancedblockentities-0.9+1.20.jar"
    "fabricskyboxes-0.7.3+mc1.20.1.jar"
    "fadeless-1.0.1.jar"
    "fastquit-3.0.0+1.20+.jar"
    "forcecloseloadingscreen-2.1.1.jar"
    "fsb-interop-1.3.6+mc1.20.1-build.50.jar"
    "indium-1.0.36+mc1.20.1.jar"
    "inventoryhud.fabric.1.20.1-3.4.26.jar"
    "iris-1.7.6+mc1.20.1.jar"
    "lambdynamiclights-4.4.0+1.20.1.jar"
    "malilib-fabric-1.20.1-0.16.3.jar"
    "modmenu-7.2.2.jar"
    "modmenu-badges-lib-2023.6.1.jar"
    "morechathistory-1.3.0.jar"
    "moreculling-1.20.1-0.24.5.jar"
    "particlerain-4.0.0-beta.10+1.20.1-fabric.jar"
    "puzzle-fabric-2.2.0+1.20.1.jar"
    "rebind_narrator-1.20.1-fabric-2025.10.21.jar"
    "reeses_sodium_options-1.7.2+mc1.20.1-build.101.jar"
    "ridingmousefix-1.0.0.jar"
    "rrls-4.0.6.1+mc1.20.1-fabric.jar"
    "screenshot_viewer-1.3.1-fabric-mc1.20.jar"
    "smoothscroll-2.2.3.1+1.20.1.jar"
    "sodium-extra-0.5.9+mc1.20.1.jar"
    "sodium-fabric-0.5.13+mc1.20.1.jar"
    "sodiumextras-fabric-1.0.7-1.20.1.jar"
    "sodiumoptionsapi-fabric-1.0.10-1.20.1.jar"
    "sodiumoptionsmodcompat-fabric-1.0.0-1.20.1.jar"
    "tia-1.20-1.1-fabric.jar"
    "visuality-0.7.1+1.20.jar"
    "zoomify-2.15.1+1.20.1.jar"
  ];

  serverExcludedModNames = pkgs.writeText "homestead-server-excluded-mods" (lib.concatStringsSep "\n" serverExcludedMods);

  serverMods = pkgs.runCommandLocal "homestead-server-mods" {} ''
    mkdir -p "$out"
    for mod in ${modpack}/mods/*; do
      name="$(${pkgs.coreutils}/bin/basename "$mod")"
      if ${pkgs.gnugrep}/bin/grep -Fxq "$name" ${serverExcludedModNames}; then
        continue
      fi
      ln -s "$mod" "$out/$name"
    done
    ${optionalString cfg.discord.enable ''
      ln -s ${discordIntegration} "$out/dcintegration-fabric-3.0.7-1.20.1.jar"
    ''}
  '';
in {
  imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];

  options.laplace.services.minecraft.retirement-home = {
    enable = mkEnableOption "Homestead Fabric Minecraft server";

    autoStart = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to start the Homestead server on boot.";
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
      default = "Homestead";
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
      description = "systemd Restart policy for the Homestead server.";
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
          level-seed = "447799994322666789963257896";
          difficulty = 3;
          spawn-protection = 1;
        };

        symlinks = {
          mods = serverMods;
          patchouli_books = "${modpack}/patchouli_books";
        };

        files =
          {
            config = "${modpack}/config";
            kubejs = "${modpack}/kubejs";
            scripts = "${modpack}/scripts";
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
