{lib}: let
  inherit (lib) mkOption types;
  options = import ./options.nix {inherit lib;};
in {
  settings =
    builtins.removeAttrs options ["openFirewall" "discord"]
    // {
      domain = mkOption {type = types.str;};
      mapDomain = mkOption {type = types.str;};
      sopsFile = mkOption {type = types.path;};
      discord = builtins.removeAttrs options.discord ["environmentFile"];
    };
  endpointNames = ["game" "voice" "http" "https" "map" "map-app" "exporter"];
  endpoints = {instance, ...}: let
    frontend = domain: port: {
      host = instance.host;
      protocol = "tcp";
      inherit port domain;
      listenAddress = "0.0.0.0";
      scope = "tailnet";
      publishDNS = port == 443;
      shared = "caddy";
    };
  in {
    game = {
      host = instance.host;
      protocol = "tcp";
      port = instance.settings.port;
      listenAddress = "0.0.0.0";
      scope = "tailnet";
      domain = instance.settings.domain;
    };
    voice = {
      host = instance.host;
      protocol = "udp";
      port = 24454;
      listenAddress = "0.0.0.0";
      scope = "tailnet";
    };
    https = frontend instance.settings.domain 443;
    http = frontend instance.settings.domain 80;
    map = frontend instance.settings.mapDomain 443;
    map-app = {
      host = instance.host;
      protocol = "tcp";
      port = 8080;
      listenAddress = "127.0.0.1";
      scope = "loopback";
    };
    exporter = {
      host = instance.host;
      protocol = "tcp";
      port = 25585;
      listenAddress = "0.0.0.0";
      scope = "lan";
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
  activation = [["laplace" "services" "minecraft" "retirement-home" "enable"] ["services" "minecraft-servers" "enable"]];

  project = {
    instance,
    cluster,
    hostName,
  }: {
    config,
    lib,
    ...
  }: {
    imports = [./frontend.nix];
    config = lib.optionalAttrs (hostName == instance.host) {
      sops.secrets = lib.optionalAttrs instance.settings.discord.enable {
        discord_bot_env.sopsFile = instance.settings.sopsFile;
      };
      laplace.services.minecraft.retirement-home =
        builtins.removeAttrs instance.settings ["sopsFile"]
        // {
          enable = true;
          openFirewall = false;
          discord =
            instance.settings.discord
            // lib.optionalAttrs instance.settings.discord.enable {
              environmentFile = config.sops.secrets.discord_bot_env.path;
            };
        };
      # spark's async-profiler samples kernel frames rather than Java-only stacks.
      boot.kernel.sysctl."kernel.perf_event_paranoid" = 1;
      services.vmagent.prometheusConfig.scrape_configs = lib.mkIf config.laplace.services.telemetry.enable (lib.mkAfter [
        {
          job_name = "minecraft";
          scrape_interval = "15s";
          scrape_timeout = "5s";
          sample_limit = 5000;
          label_limit = 40;
          static_configs = [{targets = ["127.0.0.1:${toString cluster.endpoints.minecraft.exporter.port}"];}];
        }
      ]);
    };
  };
}
