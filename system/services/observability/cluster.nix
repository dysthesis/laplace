{lib}: let
  inherit (lib) mkOption types;
  telemetry = import ../telemetry/contract.nix {inherit lib;};
  listeners = import ./listeners.nix;
  writerOptions = builtins.removeAttrs (import ./writer-options.nix {inherit lib;}) ["sourceAddress" "certificateFile"];
  remoteWriters = instance: lib.filterAttrs (name: _: name != instance.host) instance.settings.writers;
  origin = endpoint: "https://${endpoint.domain}" + lib.optionalString (endpoint.port != 443) ":${toString endpoint.port}";
in {
  settings = {
    domain = mkOption {type = types.str;};
    sopsFile = mkOption {type = types.path;};
    ingressDomain = mkOption {
      type = types.str;
      default = telemetry.domain;
    };
    metricsIngressPort = mkOption {
      type = types.port;
      default = telemetry.metricsPort;
    };
    journalIngressPort = mkOption {
      type = types.port;
      default = telemetry.journalPort;
    };
    metricsMount = mkOption {
      type = types.str;
      default = "/var/lib/private/victoriametrics";
    };
    logsMount = mkOption {
      type = types.str;
      default = "/var/lib/private/victorialogs";
    };
    expectedHosts = mkOption {type = types.listOf types.str;};
    writers = mkOption {
      default = {};
      type = types.attrsOf (types.submodule ({name, ...}: {
        options =
          writerOptions
          // {
            certificateSecret = mkOption {
              type = types.str;
              default = "telemetry_${name}_client_certificate";
            };
            sopsFile = mkOption {
              type = types.nullOr types.path;
              default = null;
            };
          };
      }));
    };
  };
  # Publicly nameable endpoints stay finite; per-writer loopback listeners are
  # generated from explicit admission declarations, not a second site roster.
  endpointNames = ["app" "http" "https" "metrics" "logs" "alertmanager" "alertmanager-cluster-tcp" "alertmanager-cluster-udp" "vmalert-metrics" "vmalert-logs" "blackbox" "metrics-ingress" "journal-ingress"];
  endpoints = {instance, ...}: let
    local = port: {
      host = instance.host;
      protocol = "tcp";
      inherit port;
      inherit (listeners) listenAddress;
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
    ingress = port: {
      host = instance.host;
      protocol = "tcp";
      inherit port;
      listenAddress = "0.0.0.0";
      scope = "lan";
      domain = instance.settings.ingressDomain;
      shared = "caddy";
    };
  in
    {
      app = local listeners.grafanaPort;
      metrics = local listeners.metricsPort;
      logs = local listeners.logsPort;
      alertmanager = local listeners.alertmanagerPort;
      alertmanager-cluster-tcp =
        (local 9094)
        // {
          listenAddress = "0.0.0.0";
          scope = "lan";
        };
      alertmanager-cluster-udp =
        (local 9094)
        // {
          protocol = "udp";
          listenAddress = "0.0.0.0";
          scope = "lan";
        };
      vmalert-metrics = local listeners.metricsAlertPort;
      vmalert-logs = local listeners.logsAlertPort;
      blackbox = local listeners.blackboxPort;
      http = frontend 80;
      https = frontend 443;
      metrics-ingress = ingress instance.settings.metricsIngressPort;
      journal-ingress = ingress instance.settings.journalIngressPort;
    }
    // lib.mapAttrs' (name: writer: lib.nameValuePair "writer-${name}" (local writer.metricsPort)) (remoteWriters instance);

  resources = instance:
    map (value: {
      kind = "path";
      inherit value;
    }) ([
        instance.settings.metricsMount
        instance.settings.logsMount
        "/var/lib/grafana"
        "/var/lib/private/alertmanager"
        "/var/backups/grafana"
      ]
      ++ map (name: "/var/cache/private/vmagent-ingress-${name}") (builtins.attrNames (remoteWriters instance)));

  validate = {
    instance,
    cluster,
  }: let
    host = cluster.hosts.${instance.host};
    missingWriters = lib.filter (name: name != instance.host && !(builtins.hasAttr name instance.settings.writers)) instance.settings.expectedHosts;
    ntfy = cluster.endpoints.ntfy.https or null;
    kuma = cluster.endpoints.uptime-kuma.https or null;
  in [
    {
      assertion = host.trust == "trusted" && host.tailnet != null && builtins.elem "persistent" host.storage && builtins.elem "observability-volumes" host.storage;
      message = "observability requires a trusted Tailnet server with persistent attached observability volumes";
    }
    {
      assertion = !instance.enable || ntfy != null;
      message = "observability alert sink requires enabled ntfy.https";
    }
    {
      assertion = !instance.enable || kuma != null;
      message = "observability dead-man heartbeat requires enabled uptime-kuma.https";
    }
    {
      assertion = !instance.enable || missingWriters == [];
      message = "observability needs explicit remote writer certificates for ${lib.concatStringsSep ", " missingWriters}; receiver relocation does not move node identities";
    }
    {
      assertion = builtins.all (name: builtins.hasAttr name cluster.hosts && cluster.hosts.${name}.lan.ip != null) instance.settings.expectedHosts;
      message = "observability expectedHosts must name managed machines with LAN addresses";
    }
    {
      assertion = builtins.all (name: builtins.hasAttr name cluster.hosts && (!instance.enable || cluster.hosts.${name}.telemetry) && builtins.elem name instance.settings.expectedHosts) (builtins.attrNames instance.settings.writers);
      message = "observability writer identities must name expectedHosts with telemetry enabled while the receiver is active";
    }
  ];
  activation = [
    ["laplace" "services" "observability" "enable"]
    ["services" "victoriametrics" "enable"]
    ["services" "victorialogs" "enable"]
    ["services" "grafana" "enable"]
    ["services" "prometheus" "alertmanager" "enable"]
  ];

  project = {
    instance,
    cluster,
    hostName,
  }: {
    config,
    lib,
    ...
  }:
    lib.optionalAttrs (hostName == instance.host) (let
      inherit (instance) settings;
      writers = remoteWriters instance;
      minecraft = cluster.activeServices.minecraft or null;
      secret = restartUnits: {
        inherit restartUnits;
        sopsFile = settings.sopsFile;
      };
    in {
      sops = {
        secrets =
          {
            ntfy_alertmanager_token = secret ["alertmanager.service"];
            uptime_kuma_push_url = secret ["alertmanager.service"];
            telemetry_ingress_client_ca = secret ["caddy.service"];
          }
          // lib.mapAttrs' (_: writer:
            lib.nameValuePair writer.certificateSecret {
              sopsFile =
                if writer.sopsFile == null
                then settings.sopsFile
                else writer.sopsFile;
              restartUnits = ["caddy.service"];
            })
          writers;
        templates."alertmanager.env".content = ''
          NTFY_ALERTMANAGER_TOKEN=${config.sops.placeholder.ntfy_alertmanager_token}
          UPTIME_KUMA_PUSH_URL=${config.sops.placeholder.uptime_kuma_push_url}
        '';
      };
      services.prometheus.alertmanager.environmentFile = config.sops.templates."alertmanager.env".path;
      laplace.services.observability = {
        enable = true;
        inherit (settings) expectedHosts metricsMount logsMount;
        minecraftHost =
          if minecraft == null
          then null
          else minecraft.host;
        ntfyOrigin = origin cluster.endpoints.ntfy.https;
        kumaOrigin = origin cluster.endpoints.uptime-kuma.https;
        frontend = {
          enable = true;
          domain = settings.domain;
        };
        ingress = {
          enable = true;
          domain = settings.ingressDomain;
          metricsPort = settings.metricsIngressPort;
          journalPort = settings.journalIngressPort;
          caFile = config.sops.secrets.telemetry_ingress_client_ca.path;
          writers = lib.mapAttrs (name: writer:
            builtins.removeAttrs writer ["certificateSecret" "sopsFile"]
            // {
              sourceAddress = cluster.hosts.${name}.lan.ip;
              certificateFile = config.sops.secrets.${writer.certificateSecret}.path;
            })
          writers;
        };
      };
    });
}
