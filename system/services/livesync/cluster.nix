{lib}: let
  common = import ../service-common.nix {inherit lib;};
in {
  settings = {
    inherit (common) domain sopsFile;
    port = lib.mkOption {
      type = lib.types.port;
      default = 5984;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/couchdb";
    };
  };
  endpointNames = ["app" "https" "http" "node" "epmd"];
  endpoints = {instance, ...}:
    common.webEndpoints instance
    // {
      app = common.appEndpoint instance;
      node = {
        host = instance.host;
        protocol = "tcp";
        port = 5986;
        listenAddress = "127.0.0.1";
        scope = "loopback";
      };
      # Erlang's node registry is not an application ingress endpoint.
      epmd = {
        host = instance.host;
        protocol = "tcp";
        port = 4369;
        listenAddress = "0.0.0.0";
        scope = "loopback";
      };
    };
  resources = instance: [
    {
      kind = "path";
      value = toString instance.settings.dataDir;
    }
    {
      kind = "uid";
      value = "106";
    }
  ];
  validate = common.validate "livesync";
  activation = [["services" "couchdb" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {config, ...}:
    lib.optionalAttrs (hostName == instance.host) {
      sops.secrets.couchdb_admin_ini = {
        sopsFile = instance.settings.sopsFile;
        owner = config.services.couchdb.user;
        group = config.services.couchdb.group;
        restartUnits = ["couchdb.service"];
      };
      services.couchdb = {
        enable = true;
        bindAddress = common.bindAddress instance.settings.listenAddress;
        inherit (instance.settings) port;
        databaseDir = instance.settings.dataDir;
        viewIndexDir = instance.settings.dataDir;
        configFile = "${instance.settings.dataDir}/local.ini";
        # Pre-hashed [admins] INI preserves the persisted identity/password semantics.
        extraConfigFiles = [config.sops.secrets.couchdb_admin_ini.path];
        extraConfig = {
          couchdb = {
            single_node = true;
            max_document_size = 50000000;
          };
          chttpd = {
            require_valid_user = true;
            enable_cors = true;
            max_http_request_size = 4294967296;
          };
          httpd = {
            enable_cors = true;
            "WWW-Authenticate" = ''Basic realm="couchdb"'';
          };
          cors = {
            credentials = true;
            origins = "app://obsidian.md,capacitor://localhost,http://localhost";
          };
        };
      };
      mnemosyne.dirs = [config.services.couchdb.databaseDir];
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "127.0.0.1" (common.appEndpoint instance);
    };
}
