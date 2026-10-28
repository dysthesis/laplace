{lib}: let
  inherit (lib) mkOption types;
in {
  settings = {
    domain = mkOption {type = types.str;};
    frontendHost = mkOption {type = types.str;};
    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
    };
    port = mkOption {
      type = types.port;
      default = 8080;
    };
    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/forgejo";
    };
    anubisPort = mkOption {
      type = types.port;
      default = 8923;
    };
  };
  endpointNames = ["app" "https" "http" "anubis"];

  endpoints = {instance, ...}: let
    inherit (instance) settings;
    frontend = port: {
      host = settings.frontendHost;
      protocol = "tcp";
      inherit port;
      listenAddress = "0.0.0.0";
      scope = "public";
      domain = settings.domain;
      shared = "caddy";
    };
  in {
    app = {
      host = instance.host;
      protocol = "tcp";
      port = settings.port;
      listenAddress = settings.listenAddress;
      scope = "lan";
    };
    https = frontend 443;
    http = frontend 80;
    anubis = {
      host = settings.frontendHost;
      protocol = "tcp";
      port = settings.anubisPort;
      listenAddress = "127.0.0.1";
      scope = "loopback";
    };
  };

  resources = instance: [
    {
      kind = "path";
      value = instance.settings.stateDir;
    }
    {
      kind = "path";
      value = "/var/lib/postgresql";
      shared = "postgresql";
    }
    {
      kind = "database";
      value = "git";
    }
    {
      kind = "database-user";
      value = "git";
    }
  ];

  validate = {
    instance,
    cluster,
  }: let
    host = cluster.hosts.${instance.host};
    frontend = cluster.hosts.${instance.settings.frontendHost} or null;
  in [
    {
      assertion = host.trust == "git" && host.tailnet == null && host.lan.ip != null && builtins.elem "persistent" host.storage;
      message = "forgejo requires a persistent non-Tailnet git server with a LAN address";
    }
    {
      assertion = builtins.elem instance.settings.listenAddress ["0.0.0.0" host.lan.ip];
      message = "forgejo listenAddress must serve the advertised LAN backend: use 0.0.0.0 or the host LAN address";
    }
    {
      assertion = frontend != null && frontend.role == "server" && frontend.deployment != null && frontend.trust == "edge" && frontend.tailnet == null && frontend.lan.ip != null;
      message = "forgejo frontendHost must be a deployable non-Tailnet edge server with a LAN address";
    }
  ];

  activation = [["laplace" "services" "forgejo" "enable"] ["services" "forgejo" "enable"]];

  project = {
    instance,
    cluster,
    hostName,
  }: {lib, ...}: let
    inherit (instance) settings;
    backend = cluster.hosts.${instance.host}.lan.ip;
    frontend = cluster.hosts.${settings.frontendHost}.lan.ip;
    runner = cluster.activeServices.forgejo-runner or null;
    allowedSources = [frontend] ++ lib.optional (runner != null) cluster.hosts.${runner.host}.lan.ip;
    anubis = "127.0.0.1:${toString settings.anubisPort}";
  in
    lib.mkMerge [
      (lib.optionalAttrs (hostName == instance.host) {
        laplace.services.forgejo = {
          enable = true;
          inherit (settings) domain listenAddress port stateDir;
          trustedProxies = ["${frontend}/32"];
        };
        networking.nftables.enable = true;
        networking.firewall.extraInputRules = ''
          ip saddr { ${lib.concatStringsSep ", " allowedSources} } tcp dport ${toString settings.port} accept
        '';
      })
      (lib.optionalAttrs (hostName == settings.frontendHost) {
        laplace.services.caddy = {
          enable = true;
          virtualHosts.${settings.domain}.extraConfig = ''
            @notSSE not header Accept *text/event-stream*
            encode @notSSE
            reverse_proxy http://${anubis} {
              header_up X-Real-Ip {client_ip}
              header_up X-Forwarded-For {client_ip}
            }
          '';
        };
        services.anubis.instances.git = {
          settings = {
            BIND = anubis;
            BIND_NETWORK = "tcp";
            TARGET = "http://${backend}:${toString settings.port}";
            XFF_STRIP_PRIVATE = false;
          };
          policy.extraBots = [
            {
              name = "git-clients";
              user_agent_regex = "^git/";
              action = "ALLOW";
            }
          ];
        };
      })
    ];
}
