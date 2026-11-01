{lib}: let
  common = import ../service-common.nix {inherit lib;};
in {
  settings = import ./settings.nix {inherit lib;};
  endpointNames = ["app"];
  endpoints = {instance, ...}: {
    # This domain publishes DNS and the site URL without a Caddy virtual host.
    app = {
      host = instance.host;
      protocol = "tcp";
      port = instance.settings.port;
      listenAddress = "127.0.0.1";
      scope = "loopback";
      domain = instance.settings.domain;
      publishDNS = true;
    };
  };
  resources = _instance: [
    {
      kind = "path";
      value = "/srv/nocodb";
    }
    {
      kind = "path";
      value = "/var/backups/nocodb";
    }
    # Preparation assigns this UID to the host-mounted PostgreSQL and Redis directories.
    {
      kind = "uid";
      value = "999";
    }
    # Container databases and listeners do not use the native PostgreSQL provider.
    {
      kind = "database";
      value = "nocodb-container/nocodb";
    }
    {
      kind = "database-user";
      value = "nocodb-container/nocodb";
    }
  ];
  validate = common.validate "nocodb";
  activation = [["laplace" "services" "nocodb" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.nocodb = instance.settings // {enable = true;};
    };
}
