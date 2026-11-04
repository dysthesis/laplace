{
  lib,
  inputs,
  self,
  extraModules ? [],
}: let
  # Keep service checks active even when production instances are absent.
  cluster = import ../../cluster {
    inherit lib;
    modules =
      [
        ../../cluster/machines.nix
        ../../cluster/access.nix
        {
          laplace.services = {
            minecraft = {
              enable = true;
              host = "loki";
              settings = {
                domain = "mc.example.test";
                mapDomain = "map.example.test";
                sopsFile = ../../system/secrets/loki.yaml;
                autoStart = true;
                restart = "on-failure";
                extraJvmOpts = "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1";
                discord.enable = true;
              };
            };
            headscale = {
              enable = true;
              host = "bifrost";
              settings = {
                domain = "headscale.example.test";
                frontendHost = "portunus";
                baseDomain = "tailnet.example.test";
                sopsFile = ../../system/secrets/bifrost.yaml;
                wgOnly = {
                  enable = true;
                  peers.fixture = {
                    userId = 2;
                    publicKeySecret = "mullvad_wg_key";
                    endpoints = ["146.70.200.2:51820"];
                    allowedIPs = ["0.0.0.0/0" "::/0"];
                    exitNodeDNSResolvers = ["10.64.0.1"];
                    tags = ["tag:mullvad" "tag:exit-node"];
                    connections.deimos = {
                      registeredNodeKey = "nodekey:ddec812440a7cc7728567fe2f8d6d97f5b8411fba6593fe4cdb5035c09a6aa53";
                      ipv4MasqAddr = "10.139.68.25";
                      ipv6MasqAddr = "fc00:bbbb:bbbb:bb01:d:0:b:4419";
                    };
                  };
                };
              };
            };
            observability = {
              enable = true;
              host = "argus";
              settings = {
                domain = "observe.example.test";
                sopsFile = ../../system/secrets/argus.yaml;
                expectedHosts = ["argus" "talos" "mneme" "mimir" "horos" "hermes" "charon" "loki" "hephaestus" "bifrost" "portunus"];
                writers = {
                  talos = {
                    role = "ci-runner";
                    metricsPort = 8430;
                    certificateFingerprint = "bf7e47c79f283095d5c4675c8fbdf9be9e8b57c806a2e0583b9820cab1397034";
                  };
                  mneme = {
                    role = "photos";
                    metricsPort = 8431;
                    certificateFingerprint = "5510a6938727d9b1360f6481b915359a3ad028f486cedeae917ab3302d87d9bd";
                  };
                  mimir = {
                    role = "apps";
                    metricsPort = 8432;
                    certificateFingerprint = "fa7365b4e32067bb3cda4bf091d8da397a01092b43c30ed2398f67d17e035d12";
                  };
                  horos = {
                    role = "notifications";
                    metricsPort = 8433;
                    certificateFingerprint = "7bd259022b7440a589a27716fbb4008b64686d66f71070a64311eb3e27a64f41";
                  };
                  hermes = {
                    role = "dns";
                    metricsPort = 8434;
                    certificateFingerprint = "44efa91be270f0179d193cd3913c881d55dda8c783c89377f409425325bf4385";
                  };
                  charon = {
                    role = "exit";
                    metricsPort = 8435;
                    certificateFingerprint = "566364714879f02173145d77b35b329d1602f91bb5333a919bf676ca26e540d8";
                  };
                  loki = {
                    role = "game";
                    metricsPort = 8436;
                    certificateFingerprint = "e7c59c344159615ee66e3afb583aaf59d38a370413e078e2402311e9fd711bed";
                  };
                  hephaestus = {
                    role = "git";
                    metricsPort = 8437;
                    certificateFingerprint = "9c254f686ca1fb96b6cc82e4216a5484df9f0808d96a2795095c1ac3e3695431";
                  };
                  bifrost = {
                    role = "control-plane";
                    metricsPort = 8438;
                    certificateFingerprint = "6ca0915346fdccfb656c6501bdcde1de53c7b94a69b9e5f8a84e9876498346ad";
                  };
                  portunus = {
                    role = "edge";
                    metricsPort = 8439;
                    certificateFingerprint = "1aae3ff3d3c81f9c89bee547f00ce27348ceada96eeef5337564a7eeebc01a45";
                  };
                };
              };
            };
            adguardhome = {
              enable = true;
              host = "hermes";
              settings = {
                domain = "dns.example.test";
                exceptionClient = "deimos";
              };
            };
            ntfy = {
              enable = true;
              host = "horos";
              settings = {
                domain = "ntfy.example.test";
                sopsFile = ../../system/secrets/horos.yaml;
              };
            };
            uptime-kuma = {
              enable = true;
              host = "horos";
              settings.domain = "uptime.example.test";
            };
            beszel-hub = {
              enable = true;
              host = "mimir";
              settings = {
                domain = "beszel.example.test";
                agentPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINq5YPgIMrkCV4JIl0DEihMUE/G3z480LbAun0TapjbO";
              };
            };
          };
        }
      ]
      ++ extraModules;
  };
  systems = (import ../../hosts {inherit lib inputs self cluster;}).nixosConfigurations;
  hostNames = lib.genAttrs ["minecraft" "headscale" "observability"] (name: cluster.manifest.services.${name}.host);
in {
  inherit cluster systems hostNames;
  minecraft = systems.${hostNames.minecraft}.config;
  headscale = systems.${hostNames.headscale}.config;
  observability = systems.${hostNames.observability}.config;
}
