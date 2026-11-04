{lib}: let
  inherit (lib) mkOption types;
  peerOptions =
    builtins.removeAttrs (import ./wg-peer-options.nix {inherit lib;}) ["publicKeyFile"]
    // {
      publicKeySecret = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Encrypted key reference in the instance sopsFile, resolved only on the selected host.";
      };
    };
in {
  settings = {
    domain = mkOption {type = types.str;};
    frontendHost = mkOption {type = types.str;};
    baseDomain = mkOption {
      type = types.str;
      default = "tailnet.dysthesis.com";
    };
    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
    };
    port = mkOption {
      type = types.port;
      default = 8080;
    };
    sopsFile = mkOption {type = types.path;};
    wgOnly = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      peers = mkOption {
        type = types.attrsOf (types.submodule {options = peerOptions;});
        default = {};
      };
    };
  };
  endpointNames = ["app" "https" "http"];
  endpoints = {instance, ...}: let
    frontend = port: {
      host = instance.settings.frontendHost;
      protocol = "tcp";
      inherit port;
      listenAddress = "0.0.0.0";
      scope = "public";
      domain = instance.settings.domain;
      shared = "caddy";
    };
  in {
    app = {
      host = instance.host;
      protocol = "tcp";
      port = instance.settings.port;
      listenAddress = instance.settings.listenAddress;
      scope = "lan";
    };
    https = frontend 443;
    http = frontend 80;
  };
  resources = _: [
    {
      kind = "path";
      value = "/var/lib/private/headscale";
    }
    {
      kind = "path";
      value = "/var/lib/headscale";
    }
  ];
  activation = [["laplace" "services" "headscale" "enable"] ["services" "headscale" "enable"]];
  validate = {
    instance,
    cluster,
  }: let
    host = cluster.hosts.${instance.host};
    frontend = cluster.hosts.${instance.settings.frontendHost} or null;
    dns = cluster.endpoints.adguardhome.dns or null;
  in
    [
      {
        assertion = host.trust == "control-plane" && host.tailnet == null && host.lan.ip != null && builtins.elem "persistent" host.storage;
        message = "headscale requires a persistent non-Tailnet control-plane server with a LAN address";
      }
      {
        assertion = builtins.elem instance.settings.listenAddress ["0.0.0.0" host.lan.ip];
        message = "headscale listenAddress must serve the advertised LAN backend: use 0.0.0.0 or the host LAN address";
      }
      {
        assertion = frontend != null && frontend.role == "server" && frontend.deployment != null && frontend.trust == "edge" && frontend.tailnet == null && frontend.lan.ip != null;
        message = "headscale frontendHost must be a deployable non-Tailnet edge server with a LAN address";
      }
      {
        assertion = !instance.enable || (dns != null && dns.port == 53 && cluster.hosts.${dns.host}.tailnet != null);
        message = "headscale resolver advertisement requires enabled adguardhome.dns on Tailnet port 53";
      }
      {
        assertion = !instance.settings.wgOnly.enable || instance.settings.wgOnly.peers != {};
        message = "headscale WG-only reconciliation requires declared peers";
      }
    ]
    ++ lib.mapAttrsToList (name: peer: {
      assertion = (peer.publicKey != null) != (peer.publicKeySecret != null);
      message = "headscale WG-only peer ${name} requires exactly one publicKey or publicKeySecret";
    })
    instance.settings.wgOnly.peers;

  project = {
    instance,
    cluster,
    hostName,
  }: {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    inherit (instance) settings;
    backend = cluster.hosts.${instance.host}.lan.ip;
    frontend = cluster.hosts.${settings.frontendHost}.lan.ip;
    dns = cluster.endpoints.adguardhome.dns;
    peers = lib.mapAttrs (_: peer:
      builtins.removeAttrs peer ["publicKeySecret"]
      // lib.optionalAttrs (peer.publicKeySecret != null) {
        publicKeyFile = config.sops.secrets.${peer.publicKeySecret}.path;
      })
    settings.wgOnly.peers;
    secrets = lib.unique (lib.filter (name: name != null) (lib.mapAttrsToList (_: peer: peer.publicKeySecret) settings.wgOnly.peers));
  in
    lib.mkMerge [
      (lib.optionalAttrs (hostName == instance.host) {
        services.headscale.package = inputs.headscale.packages.${pkgs.stdenv.hostPlatform.system}.default;
        sops.secrets = lib.optionalAttrs settings.wgOnly.enable (lib.genAttrs secrets (_: {sopsFile = settings.sopsFile;}));
        laplace.services.headscale = {
          enable = true;
          openFirewall = false;
          fqdn = settings.domain;
          address = settings.listenAddress;
          inherit (settings) port baseDomain;
          acl.enable = true;
          wgOnly = {
            inherit (settings.wgOnly) enable;
            inherit peers;
          };
          settings.dns = {
            override_local_dns = true;
            nameservers.global = [cluster.hosts.${dns.host}.tailnet.ip];
            extra_records = cluster.network.dnsRecords;
          };
        };
        networking = {
          nftables.enable = true;
          hosts.${frontend} = [settings.domain];
          firewall.extraInputRules = ''
            ip saddr ${frontend}/32 tcp dport ${toString settings.port} accept
          '';
        };
      })
      (lib.optionalAttrs (hostName == settings.frontendHost) {
        laplace.services.caddy.enable = true;
        services.caddy.virtualHosts.${settings.domain}.extraConfig = ''
            @notSSE not header Accept *text/event-stream*
            encode @notSSE
            reverse_proxy http://${backend}:${toString settings.port}
          '';
      })
    ];
}
