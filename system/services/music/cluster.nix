{lib}: {
  settings = import ./settings.nix {inherit lib;};
  endpointNames = ["app" "https" "http" "flaresolverr" "prowlarr" "lidarr" "slskd" "soulseek" "qbittorrent"];
  endpoints = {instance, ...}: let
    local = port: {
      host = instance.host;
      protocol = "tcp";
      inherit port;
      listenAddress = "127.0.0.1";
      scope = "loopback";
    };
    frontend = port: {
      host = instance.host;
      protocol = "tcp";
      inherit port;
      listenAddress = "0.0.0.0";
      scope = "tailnet";
      domain = instance.settings.domain;
      publishDNS = port == 443;
      shared = "caddy";
    };
  in {
    app = local 4533;
    flaresolverr = local 8191;
    prowlarr = local 9696;
    lidarr = local 8686;
    slskd = local 5030;
    qbittorrent = local 8080;
    soulseek = {
      host = instance.host;
      protocol = "tcp";
      port = 50300;
      listenAddress = "0.0.0.0";
      scope = "lan";
    };
    https = frontend 443;
    http = frontend 80;
  };
  resources = _:
    map (value: {
      kind = "path";
      inherit value;
    }) [
      "/var/lib/private/prowlarr"
      "/var/lib/lidarr"
      "/var/lib/slskd"
      "/var/lib/soularr"
      "/var/lib/qBittorrent"
      "/var/lib/navidrome"
      "/srv/media"
    ];
  validate = {
    instance,
    cluster,
  }: let
    host = cluster.hosts.${instance.host};
  in [
    {
      assertion = host.trust == "trusted" && host.tailnet != null && builtins.elem "persistent" host.storage && builtins.elem "media" host.storage;
      message = "music requires a trusted Tailnet server with persistent media storage";
    }
  ];
  activation = [
    ["laplace" "services" "music" "enable"]
    ["services" "flaresolverr" "enable"]
    ["services" "prowlarr" "enable"]
    ["services" "lidarr" "enable"]
    ["services" "slskd" "enable"]
    ["services" "qbittorrent" "enable"]
    ["services" "navidrome" "enable"]
  ];
  project = {
    instance,
    hostName,
    ...
  }: _:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.music = {enable = true;} // instance.settings;
    };
}
