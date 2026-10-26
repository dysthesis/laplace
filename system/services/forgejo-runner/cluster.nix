{lib}: let
  inherit (lib) mkOption types;
in {
  settings = {
    instanceName = mkOption {
      type = types.strMatching "[a-z0-9][a-z0-9-]*";
      description = "Stable runner registration identity; independent of placement.";
    };
    sopsFile = mkOption {type = types.path;};
    tokenSecret = mkOption {
      type = types.str;
      default = "action_runner";
    };
    labels = mkOption {
      type = types.listOf types.str;
      default = ["nix:host"];
    };
  };
  endpointNames = [];
  endpoints = _: {};
  resources = _: [
    {
      kind = "path";
      value = "/var/lib/private/gitea-runner";
    }
  ];
  activation = [["laplace" "services" "forgejo-runner" "enable"]];

  validate = {
    instance,
    cluster,
  }: let
    host = cluster.hosts.${instance.host};
    forgejo = cluster.activeServices.forgejo or null;
  in [
    {
      assertion = host.trust == "ci" && host.tailnet == null && host.lan.ip != null && builtins.elem "persistent" host.storage;
      message = "forgejo-runner requires a persistent non-Tailnet CI server with a LAN address";
    }
    {
      assertion = !instance.enable || (forgejo != null && forgejo.host != instance.host);
      message = "forgejo-runner requires enabled forgejo on a separate git server";
    }
    {
      assertion = builtins.any (lib.hasPrefix "nix:") instance.settings.labels;
      message = "forgejo-runner labels must retain the nix: workflow contract";
    }
  ];

  project = {
    instance,
    cluster,
    hostName,
  }: {config, ...}:
    lib.optionalAttrs (hostName == instance.host) (let
      inherit (instance) settings;
      provider = cluster.endpoints.forgejo.app;
    in {
      sops.secrets.${settings.tokenSecret}.sopsFile = settings.sopsFile;
      laplace.services.forgejo-runner = {
        enable = true;
        inherit (settings) instanceName labels;
        url = "http://${cluster.hosts.${provider.host}.lan.ip}:${toString provider.port}";
        tokenFile = config.sops.secrets.${settings.tokenSecret}.path;
      };
    });
}
