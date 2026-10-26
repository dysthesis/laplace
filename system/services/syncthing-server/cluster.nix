{lib}: let
  common = import ../personal-common.nix {inherit lib;};
in {
  settings = {
    inherit (common) domain;
    port = lib.mkOption {
      type = lib.types.port;
      default = 8384;
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/syncthing";
    };
    guiClients = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Tailnet node identities permitted to reach the otherwise unauthenticated GUI.";
    };
  };
  endpointNames = ["app" "https" "http" "transfer" "transfer-quic" "discovery"];
  endpoints = {instance, ...}:
    common.webEndpoints instance
    // {
      app = common.appEndpoint instance;
      transfer = {
        host = instance.host;
        protocol = "tcp";
        port = 22000;
        listenAddress = "0.0.0.0";
        scope = "tailnet";
      };
      transfer-quic = {
        host = instance.host;
        protocol = "udp";
        port = 22000;
        listenAddress = "0.0.0.0";
        scope = "tailnet";
      };
      discovery = {
        host = instance.host;
        protocol = "udp";
        port = 21027;
        listenAddress = "0.0.0.0";
        scope = "lan";
      };
    };
  resources = instance: [
    {
      kind = "path";
      value = toString instance.settings.dataDir;
    }
    {
      kind = "uid";
      value = "237";
    }
  ];
  validate = {
    instance,
    cluster,
  }:
    common.validate "syncthing-server" {inherit instance cluster;}
    ++ map (name: {
      assertion = builtins.hasAttr name cluster.nodes;
      message = "syncthing-server GUI client '${name}' is not a known Tailnet node identity.";
    })
    instance.settings.guiClients;
  activation = [["services" "syncthing" "enable"]];
  project = {
    instance,
    cluster,
    hostName,
  }: {config, ...}: let
    clientAddresses = lib.concatMap (name: [cluster.nodes.${name}.ip cluster.nodes.${name}.ip6]) instance.settings.guiClients;
  in
    lib.optionalAttrs (hostName == instance.host) {
      services.syncthing = {
        enable = true;
        dataDir = instance.settings.dataDir;
        guiAddress = common.hostPort instance.settings.listenAddress instance.settings.port;
        # Transfer ingress remains the identity-aware node mesh, not a global port.
        openDefaultPorts = false;
      };
      mnemosyne.dirs = [config.services.syncthing.dataDir];
      systemd.tmpfiles.rules = [
        "d ${config.services.syncthing.dataDir} 0700 syncthing syncthing - -"
      ];
      laplace.services.caddy.virtualHosts.${instance.settings.domain}.extraConfig = ''
        tls {
          dns cloudflare {env.CF_API_TOKEN}
          resolvers 1.1.1.1
        }
        # Shared HTTPS grants are not per-vhost authorization.
        @syncClients remote_ip ${lib.concatStringsSep " " clientAddresses}
        handle @syncClients {
          reverse_proxy ${common.dial "127.0.0.1" (common.appEndpoint instance)} {
            header_up Host {upstream_hostport}
          }
        }
        handle {
          respond 403
        }
      '';
    };
}
