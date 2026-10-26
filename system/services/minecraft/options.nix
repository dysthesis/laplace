{lib}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  domain = mkOption {
    type = types.str;
    default = "mc.dysthesis.com";
    description = "Published game and PackWiz hostname.";
  };
  mapDomain = mkOption {
    type = types.str;
    default = "map.dysthesis.com";
    description = "Published Squaremap hostname.";
  };
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
}
