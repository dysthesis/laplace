{
  lib,
  inputs,
  self,
}: let
  build = extra: let
    fixture = import ./service-fixtures.nix {
      inherit lib inputs self;
      extraModules = [
        {
          laplace.services = {
            miniflux = {
              host = "mimir";
              settings = {
                domain = "rss.example.test";
                sopsFile = ../../system/secrets/mimir.yaml;
                listenAddress = "0.0.0.0";
                useKarakeepBrowser = true;
              };
            };
            karakeep = {
              host = "mimir";
              settings.domain = "read.example.test";
            };
            silverbullet = {
              host = "mimir";
              settings.domain = "notes.example.test";
            };
            forgejo = {
              host = "hephaestus";
              settings = {
                domain = "git.example.test";
                frontendHost = "portunus";
              };
            };
            forgejo-runner = {
              host = "talos";
              settings = {
                instanceName = "fixture-runner";
                sopsFile = ../../system/secrets/talos.yaml;
              };
            };
          };
        }
        extra
      ];
    };
    inherit (fixture) cluster;
    hosts = import ../../hosts {inherit lib inputs self cluster;};
    hive = inputs.colmena.lib.makeHive (import ../deploy {
      inherit lib inputs self;
      inherit (hosts) nodeModules;
      cluster = cluster.manifest;
    });
  in {inherit hosts hive cluster;};
  rejected = extra: let
    fixture = build extra;
  in
    !(builtins.tryEval fixture.hosts.nixosConfigurations.charon.config.networking.hostName).success
    && !(builtins.tryEval fixture.hive.nodes.charon.config.networking.hostName).success;
  moved = build {laplace.services.silverbullet.host = lib.mkForce "horos";};
  before = moved.hosts.nixosConfigurations.mimir.config;
  after = moved.hosts.nixosConfigurations.horos.config;
  colocated = build {
    laplace.services.miniflux = {
      host = lib.mkForce "mneme";
      settings.useKarakeepBrowser = lib.mkForce false;
    };
    laplace.services.immich = {
      host = "mneme";
      settings.domain = "photos.example.test";
    };
  };
  postgres = colocated.hosts.nixosConfigurations.mneme.config;
  withoutReceiver = build {
    laplace.hosts = lib.mapAttrs (_: _: {telemetry = lib.mkForce false;}) moved.cluster.manifest.hosts;
    laplace.services = {
      observability.enable = lib.mkForce false;
      silverbullet.host = lib.mkForce "argus";
    };
  };
  remainingApp = withoutReceiver.hosts.nixosConfigurations.argus.config;
  cases = {
    desktop = rejected {laplace.services.minecraft.host = lib.mkForce "deimos";};
    installer = rejected {laplace.services.miniflux.host = lib.mkForce "chaos";};
    externalPeer = rejected {laplace.services.miniflux.host = lib.mkForce "nyx";};
    unknownHost = rejected {laplace.services.miniflux.host = lib.mkForce "typo";};
    disabledInvalid = rejected {
      laplace.services.miniflux = {
        enable = false;
        host = lib.mkForce "deimos";
      };
    };
    undeployable = rejected {laplace.hosts.mimir.deployment = lib.mkForce null;};
    disabledHub = rejected {laplace.services.beszel-hub.enable = false;};
    disabledReceiver = rejected {laplace.services.observability.enable = false;};
    disabledBrowser = rejected {laplace.services.karakeep.enable = false;};
    disabledResolver = rejected {laplace.services.adguardhome.enable = false;};
    disabledForgejo = rejected {laplace.services.forgejo.enable = false;};
    reservedAdminGroup = rejected {laplace.tailnet.guests.admin.users = ["alice"];};
    restrictedForwarding = rejected {
      laplace.tailnet.nodeFlows = [
        {
          from.role = "workstation";
          to.role = "exit";
          ports = ["tcp/443"];
          forwarding = true;
        }
      ];
    };
    sameRecipeConflict = rejected {laplace.services.minecraft.settings.port = 443;};
    unreachableBackendBinds = lib.all (service:
      lib.all (listenAddress:
        rejected {
          laplace.services.${service}.settings.listenAddress = lib.mkForce listenAddress;
        }) ["127.0.0.1" "localhost" "::1" "[::1]" "192.0.2.99"]) ["forgejo" "headscale"];
    reachableBackendBinds = lib.all (service: let
      host = moved.cluster.manifest.services.${service}.host;
    in
      lib.all (listenAddress:
        builtins.deepSeq
        (build {
          laplace.services.${service}.settings.listenAddress = lib.mkForce listenAddress;
        }).cluster.manifest
        true) ["0.0.0.0" moved.cluster.manifest.hosts.${host}.lan.ip]) ["forgejo" "headscale"];
    reassignment =
      !before.services.silverbullet.enable
      && after.services.silverbullet.enable
      && !(before.services.caddy.virtualHosts ? "notes.example.test")
      && after.services.caddy.virtualHosts ? "notes.example.test"
      && moved.cluster.manifest.hosts.mimir.deployment != null
      && moved.cluster.manifest.network.aliases.service-silverbullet-https-v6 == "fd7a:115c:a1e0::23/128"
      && moved.hive.nodes.horos.config.services.silverbullet.enable
      && lib.all (a: a.assertion) (before.assertions ++ after.assertions ++ moved.hive.nodes.horos.config.assertions);
    independentCaddy =
      remainingApp.services.caddy.enable
      && remainingApp.services.caddy.virtualHosts ? "notes.example.test"
      && !(remainingApp.services.caddy.virtualHosts ? "observe.example.test")
      && !remainingApp.services.grafana.enable
      && lib.all (a: a.assertion) remainingApp.assertions;
    sharedPostgres =
      postgres.services.miniflux.enable
      && postgres.services.immich.enable
      && builtins.elem "miniflux" postgres.services.postgresql.ensureDatabases
      && builtins.elem "immich" postgres.services.postgresql.ensureDatabases
      && builtins.elem "/var/lib/postgresql" postgres.mnemosyne.dirs
      && !(builtins.elem "/var/lib/postgresql/16" postgres.mnemosyne.dirs)
      && lib.all (a: a.assertion) postgres.assertions;
  };
in
  assert lib.assertMsg (lib.all (x: x) (builtins.attrValues cases))
  "cluster invalid declaration escaped a NixOS or checked Colmena entrypoint"; cases
