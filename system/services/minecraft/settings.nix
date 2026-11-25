{lib}: let
  inherit (lib) mkOption types;
in {
  domain = mkOption {
    type = types.str;
    description = "Published game and PackWiz hostname.";
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
}
