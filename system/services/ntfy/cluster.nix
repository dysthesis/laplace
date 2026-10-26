{lib}: let
  common = import ../personal-common.nix {inherit lib;};
in {
  settings = {
    inherit (common) domain sopsFile;
    port = lib.mkOption {
      type = lib.types.port;
      default = 2586;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
  };
  endpointNames = ["app" "https" "http"];
  endpoints = {instance, ...}: common.webEndpoints instance // {app = common.appEndpoint instance;};
  resources = _instance: [
    {
      kind = "path";
      value = "/var/lib/private/ntfy-sh";
    }
  ];
  validate = common.validate "ntfy";
  activation = [["services" "ntfy-sh" "enable"]];
  project = {
    instance,
    hostName,
    ...
  }: {config, ...}:
    lib.optionalAttrs (hostName == instance.host) {
      services.ntfy-sh = {
        enable = true;
        environmentFile = config.sops.secrets.ntfy_env.path;
        settings = {
          base-url = "https://${instance.settings.domain}";
          listen-http = common.hostPort instance.settings.listenAddress instance.settings.port;
          behind-proxy = true;
          auth-default-access = "deny-all";
          enable-login = true;
          enable-signup = false;
          require-login = true;
          keepalive-interval = "45s";
          upstream-base-url = "https://ntfy.sh";
        };
      };
      sops.secrets = {
        ntfy_env = {
          sopsFile = instance.settings.sopsFile;
          restartUnits = ["ntfy-sh.service"];
        };
        # Preserved for operator retrieval; only the hash reaches ntfy's environment.
        ntfy_admin_password.sopsFile = instance.settings.sopsFile;
      };
      mnemosyne.dirs = ["/var/lib/private/ntfy-sh"];
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "localhost" (common.appEndpoint instance);
    };
}
