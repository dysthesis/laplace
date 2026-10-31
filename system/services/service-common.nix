{lib}: rec {
  domain = lib.mkOption {
    type = lib.types.str;
    description = "Application hostname; recipes explicitly declare whether it owns a route and DNS record.";
  };
  sopsFile = lib.mkOption {
    type = lib.types.path;
    description = "Encrypted source of this application's existing credentials, independent of placement.";
  };

  # Host:port syntax brackets IPv6, but never changes the listening address.
  bindAddress = address: lib.removeSuffix "]" (lib.removePrefix "[" address);
  hostAddress = address:
    if lib.hasInfix ":" address
    then "[${bindAddress address}]"
    else address;
  hostPort = address: port: "${hostAddress address}:${toString port}";
  # Wildcard listeners are dialled locally; preserve each route's historical
  # IPv4 loopback spelling without redirecting specific non-loopback binds.
  dial = defaultDial: endpoint:
    hostPort (
      if builtins.elem endpoint.listenAddress ["0.0.0.0" "127.0.0.1" "localhost"]
      then defaultDial
      else if builtins.elem endpoint.listenAddress ["::" "[::]"]
      then "::1"
      else endpoint.listenAddress
    )
    endpoint.port;

  appEndpoint = instance: {
    host = instance.host;
    protocol = "tcp";
    port = instance.settings.port;
    listenAddress = instance.settings.listenAddress;
    scope =
      if builtins.elem instance.settings.listenAddress ["127.0.0.1" "localhost" "::1" "[::1]"]
      then "loopback"
      else "tailnet";
  };
  webEndpoints = instance: {
    https = {
      host = instance.host;
      protocol = "tcp";
      port = 443;
      listenAddress = "0.0.0.0";
      scope = "tailnet";
      domain = instance.settings.domain;
      publishDNS = true;
      shared = "caddy";
    };
    http = {
      host = instance.host;
      protocol = "tcp";
      port = 80;
      listenAddress = "0.0.0.0";
      scope = "tailnet";
      domain = instance.settings.domain;
      shared = "caddy";
    };
  };
  postgresEndpoint = instance: {
    host = instance.host;
    protocol = "tcp";
    port = 5432;
    listenAddress = "localhost";
    scope = "loopback";
    shared = "postgresql";
  };
  postgresResources = database: [
    {
      kind = "path";
      value = "/var/lib/postgresql";
      shared = "postgresql";
    }
    {
      kind = "database-version";
      value = "16";
    }
    {
      kind = "database";
      value = database;
    }
    {
      kind = "database-user";
      value = database;
    }
  ];
  validate = name: {
    instance,
    cluster,
  }: let
    host = cluster.hosts.${instance.host} or null;
  in [
    {
      assertion = host != null && host.role == "server" && host.trust == "trusted" && host.tailnet != null && builtins.elem "persistent" host.storage;
      message = "${name} requires a trusted Tailnet server with persistent storage.";
    }
  ];
}
