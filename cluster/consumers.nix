{
  cluster,
  hostName,
}: {
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  common = import ../system/services/personal-common.nix {inherit lib;};
  active = name: cluster.activeServices ? ${name};
  hasHub = active "beszel-hub";
  hasReceiver = active "observability";
  hub = cluster.services.beszel-hub;
  receiver = cluster.services.observability;
  host = cluster.hosts.${hostName};
  telemetry = config.laplace.services.telemetry;
  agent = config.laplace.services.beszel.agent;
  localReceiver = hasReceiver && receiver.host == hostName;
  hubAddress =
    if hasHub
    then cluster.hosts.${hub.host}
    else null;
  metrics = cluster.endpoints.observability.metrics-ingress;
  journal = cluster.endpoints.observability.journal-ingress;
  origin = e: "https://${e.domain}:${toString e.port}";
in {
  config = mkMerge [
    {
      laplace.services.telemetry.enable = host.telemetry;
      laplace.services.beszel.agent = {
        enable = host.beszel != null;
        mode =
          if host.beszel == null
          then "push"
          else host.beszel;
      };
      assertions = [
        {
          assertion = !telemetry.enable || hasReceiver;
          message = "cluster: telemetry on ${hostName} requires enabled observability";
        }
        {
          assertion = !agent.enable || hasHub;
          message = "cluster: Beszel agent on ${hostName} requires enabled beszel-hub";
        }
        {
          assertion = config.laplace.services.tailscale.enable == (host.tailnet != null);
          message = "cluster: ${hostName} Tailnet membership must match explicit managed identity";
        }
        {
          assertion = telemetry.enable == host.telemetry && agent.enable == (host.beszel != null);
          message = "cluster: ${hostName} machine consumers must be declared in the host inventory";
        }
        {
          assertion = !telemetry.enable || localReceiver || (telemetry.metrics.certificateFile != null && telemetry.journal.certificateFile != null);
          message = "cluster: remote telemetry writer ${hostName} needs its own client identity before observability relocation";
        }
      ];
    }
    (lib.optionalAttrs hasReceiver {
      networking.hosts = lib.mkIf (telemetry.enable && !localReceiver) {
        ${cluster.hosts.${receiver.host}.lan.ip} = [metrics.domain];
      };
      laplace.services.telemetry = mkIf telemetry.enable {
        metrics = {
          origin = lib.mkDefault (origin metrics);
          remoteWriteUrl = mkIf localReceiver "http://127.0.0.1:8428/api/v1/write";
        };
        journal = {
          origin = lib.mkDefault (origin journal);
          url = mkIf localReceiver "http://127.0.0.1:9428/insert/journald";
        };
      };
    })
    (lib.optionalAttrs hasHub (mkIf (agent.enable && agent.mode == "push") {
      laplace.services.beszel.agent.hubUrl =
        if hub.host == hostName
        then "http://${common.dial "localhost" cluster.endpoints.beszel-hub.app}"
        else "https://${cluster.endpoints.beszel-hub.https.domain}";
      networking.hosts = lib.optionalAttrs config.laplace.services.tailscale.denyDNS {
        ${hubAddress.tailnet.ip} = [cluster.endpoints.beszel-hub.https.domain];
      };
    }))
    (lib.optionalAttrs hasHub (mkIf (agent.enable && agent.mode == "pull") {
      laplace.services.beszel.agent = {
        key = hub.settings.agentPublicKey;
        trustedHubs = [
          (
            if host.tailnet != null
            then hubAddress.tailnet.ip
            else hubAddress.lan.ip
          )
        ];
      };
    }))
  ];
}
