{lib}: let
  common = import ../personal-common.nix {inherit lib;};
in {
  settings = import ./settings.nix {inherit lib;};
  endpointNames = ["app"];
  endpoints = {instance, ...}: {
    # Existing DNS/site URL only: NocoDB deliberately has no Caddy vhost.
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
    # Preparation chowns the host-mounted PostgreSQL/Redis trees to this UID.
    {
      kind = "uid";
      value = "999";
    }
    # Container listeners/databases are not the native PostgreSQL provider.
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
