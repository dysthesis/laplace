{lib}: let
  inherit (lib) mkOption types;
  options = import ./options.nix {inherit lib;};
in {
  # Keep only machine-level settings. Retirement owns the loader, mods and Java.
  settings =
    builtins.removeAttrs options ["openFirewall" "discord" "mapDomain" "memoryGb" "extraJvmOpts"]
    // {
      domain = mkOption {type = types.str;};
    };
  endpointNames = ["game" "voice"];
  endpoints = {instance, ...}: {
    game = {
      host = instance.host;
      protocol = "tcp";
      port = instance.settings.port;
      listenAddress = "0.0.0.0";
      scope = "tailnet";
      domain = instance.settings.domain;
      # The old HTTPS frontend used to publish this DNS name.
      publishDNS = true;
    };
    voice = {
      host = instance.host;
      protocol = "udp";
      port = 24454;
      listenAddress = "0.0.0.0";
      scope = "tailnet";
    };
  };
  resources = instance: [
    {
      kind = "path";
      value = instance.settings.dataDir;
    }
    {
      kind = "path";
      value = "/nix/.mc-snapshots";
    }
  ];
  validate = {
    instance,
    cluster,
  }: let
    host = cluster.hosts.${instance.host};
  in [
    {
      assertion = host.trust == "game" && host.tailnet != null && builtins.elem "persistent" host.storage && builtins.elem "btrfs" host.storage;
      message = "minecraft requires an isolated game Tailnet server with persistent Btrfs world/snapshot storage";
    }
  ];
  activation = [
    ["services" "minecraft-servers" "enable"]
    ["services" "minecraft-servers" "servers" "retirement-home" "enable"]
  ];

  project = {
    instance,
    hostName,
    ...
  }: {lib, ...}: {
    config = lib.optionalAttrs (hostName == instance.host) {
      # Retirement supplies the NeoForge package, Java runtime and modpack.
      # Laplace supplies deployment policy and persistent storage.
      services.minecraft-servers = {
        dataDir = instance.settings.dataDir;
        openFirewall = lib.mkForce false;
        managementSystem = {
          tmux.enable = false;
          systemd-socket.enable = true;
        };
        servers.retirement-home = {
          autoStart = lib.mkForce instance.settings.autoStart;
          openFirewall = lib.mkForce false;
          enableReload = true;
          restart = lib.mkForce instance.settings.restart;
          serverProperties = {
            server-port = lib.mkForce instance.settings.port;
            max-players = lib.mkForce instance.settings.maxPlayers;
            motd = lib.mkForce instance.settings.motd;
            view-distance = instance.settings.viewDistance;
            simulation-distance = instance.settings.simulationDistance;
            online-mode = true;
            white-list = true;
            enforce-whitelist = true;
            enable-rcon = false;
          };
        };
      };
      mnemosyne.dirs = [instance.settings.dataDir];
      # Spark's async-profiler needs access to native kernel call frames.
      boot.kernel.sysctl."kernel.perf_event_paranoid" = 1;
    };
  };
}
