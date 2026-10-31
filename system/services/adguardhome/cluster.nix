{lib}: let
  common = import ../service-common.nix {inherit lib;};
  runtimeSettings = import ./settings.nix {inherit lib;};
in {
  settings =
    builtins.removeAttrs runtimeSettings ["exceptionClientAddress"]
    // {
      inherit (common) domain;
      exceptionClient = lib.mkOption {
        type = lib.types.str;
        description = "Tailnet node identity used by the existing per-client allow rule.";
      };
    };
  endpointNames = ["app" "https" "dns" "dns-tcp" "dns-lan" "dns-tcp-lan"];
  endpoints = {instance, ...}: let
    dns = {
      host = instance.host;
      protocol = "udp";
      port = 53;
      listenAddress = "0.0.0.0";
      scope = "tailnet";
      shared = "adguard-dns";
    };
    dnsTCP = dns // {protocol = "tcp";};
  in
    builtins.removeAttrs (common.webEndpoints instance) ["http"]
    // {
      app = common.appEndpoint instance;
      inherit dns;
      dns-tcp = dnsTCP;
      dns-lan = dns // {scope = "lan";};
      dns-tcp-lan = dnsTCP // {scope = "lan";};
    };
  resources = _instance: [
    {
      kind = "path";
      value = "/var/lib/private/AdGuardHome";
    }
  ];
  validate = {
    instance,
    cluster,
  }:
    common.validate "adguardhome" {inherit instance cluster;}
    ++ [
      {
        assertion = builtins.hasAttr instance.settings.exceptionClient cluster.nodes;
        message = "adguardhome exceptionClient '${instance.settings.exceptionClient}' must identify a known Tailnet node.";
      }
      {
        assertion = cluster.hosts.${instance.host}.dnsListenerAvailable;
        message = "adguardhome requires a machine with port 53 reserved for the DNS service, not resolved/Unbound";
      }
    ];
  activation = [["laplace" "services" "adguardhome" "enable"] ["services" "adguardhome" "enable"]];
  project = {
    instance,
    cluster,
    hostName,
  }: {...}:
    lib.optionalAttrs (hostName == instance.host) {
      laplace.services.adguardhome = {
        enable = true;
        inherit (instance.settings) port upstreamDNS;
        # Upstream appends :port to host when generating http.address.
        listenAddress = common.hostAddress instance.settings.listenAddress;
        exceptionClientAddress = cluster.nodes.${instance.settings.exceptionClient}.ip;
      };
      # Only AdGuard's :80 listener conflicts with Caddy's HTTP redirects.
      services.caddy.globalConfig = lib.mkIf (instance.settings.port == 80) "auto_https disable_redirects";
      laplace.services.caddy.cloudflare.proxies.${instance.settings.domain} = common.dial "localhost" (common.appEndpoint instance);
    };
}
