{lib}: let
  evaluate = modules: import ../../cluster {inherit lib modules;};
  host = ip: ip6: {
    system = "x86_64-linux";
    role = "server";
    trust = "trusted";
    storage = ["persistent"];
    caddy = true;
    dnsListenerAvailable = true;
    lan.ip = "10.1.0.${ip}";
    deployment = {};
    tailnet = {
      ip = "100.64.1.${ip}";
      ip6 = "fd7a:115c:a1e0::${ip6}";
      tags = ["owner-device"];
    };
  };
  machines.laplace = {
    hosts = {
      alpha = host "1" "101";
      beta = host "2" "102";
      desktop = {
        system = "x86_64-linux";
        role = "workstation";
        trust = "client";
      };
      installer = {
        system = "x86_64-linux";
        role = "installer";
        trust = "client";
      };
      offline = (host "3" "103") // {deployment = null;};
      game =
        (host "4" "104")
        // {
          trust = "game";
          storage = ["persistent" "btrfs"];
          tailnet = {
            ip = "100.64.1.4";
            ip6 = "fd7a:115c:a1e0::104";
            tags = ["game"];
          };
        };
    };
    tailnet = {
      peers.reader = {
        ip = "100.64.1.5";
        ip6 = "fd7a:115c:a1e0::105";
        tags = ["reader"];
      };
      guests.friends.users = ["alice" "bob"];
      guests.family.users = ["alice"];
    };
  };
  app = name: target: {
    host = target;
    settings.domain = "${name}.example.test";
  };
  silver = app "notes" "alpha";
  miniflux =
    (app "rss" "alpha")
    // {
      settings = {
        domain = "rss.example.test";
        sopsFile = "/fixture/credentials.yaml";
        listenAddress = "0.0.0.0";
      };
    };
  resolver = {
    host = "beta";
    settings = {
      domain = "dns.example.test";
      exceptionClient = "reader";
    };
  };
  model = settings: (evaluate [machines {laplace = settings;}]).manifest;
  success = modules: (builtins.tryEval (builtins.deepSeq (evaluate modules).manifest true)).success;
  rejected = settings: !success [machines {laplace = settings;}];
  listenerPair = left: right: {
    services = {
      silverbullet = {
        host = "alpha";
        settings = {
          domain = "notes.example.test";
          listenAddress = left;
        };
      };
      vikunja = {
        host = "alpha";
        settings = {
          domain = "tasks.example.test";
          listenAddress = right;
          port = 8101;
        };
      };
    };
  };
  enabled = model {services.silverbullet = silver;};
  disabled = model {services.silverbullet = silver // {enable = false;};};
  grant = from: service: endpoint: {
    inherit from;
    to = {inherit service endpoint;};
  };
  network = {
    serviceGrants = [
      (grant {role = "reader";} "miniflux" "direct")
      (grant {knownNodes = true;} "adguardhome" "dns")
      (grant {guest = "friends";} "miniflux" "https")
      (grant {guest = "family";} "silverbullet" "https")
    ];
  };
  source = model {
    services = {
      inherit miniflux;
      adguardhome = resolver;
      silverbullet = silver;
    };
    tailnet = network;
  };
  moved = model {
    services = {
      miniflux = miniflux // {host = "beta";};
      adguardhome = resolver // {host = "alpha";};
      silverbullet = silver // {host = "beta";};
    };
    tailnet = network;
  };
  stopped = model {
    services = {
      miniflux = miniflux // {enable = false;};
      adguardhome = resolver;
      silverbullet = silver;
    };
    tailnet = network;
  };
  checks = {
    absent = (model {}).activeServices == {};
    declaredEnables = attrNames enabled.activeServices == ["silverbullet"];
    disabledRemovesEndpoints = disabled.activeServices == {} && disabled.endpoints == {};
    disabledRetainsHost = disabled.services.silverbullet.host == "alpha" && disabled.hosts.alpha.deployment != null;
    unknownService = rejected {services.minifluux = miniflux;};
    unknownSetting = rejected {services.miniflux = miniflux // {settings = miniflux.settings // {porrt = 80;};};};
    missingHost = rejected {services.silverbullet.settings.domain = "notes.example.test";};
    invalidTargets = lib.all (target: rejected {services.silverbullet = silver // {host = target;};}) ["desktop" "installer" "reader" "missing" "offline"];
    invalidDisabled = rejected {
      services.silverbullet =
        silver
        // {
          host = "desktop";
          enable = false;
        };
    };
    invalidDisabledSetting = rejected {
      services.miniflux =
        miniflux
        // {
          enable = false;
          settings = miniflux.settings // {port = 70000;};
        };
    };
    conflictingAssignment = !success [machines {laplace.services.silverbullet = silver;} {laplace.services.silverbullet.host = "beta";}];
    globalStrictness = !(builtins.tryEval (builtins.seq (evaluate [machines {laplace.services.silverbullet = silver // {host = "desktop";};}]).hostModule true)).success;
    syncthingExternalGUI = lib.all (listenAddress:
      rejected {
        services.syncthing-server = {
          host = "alpha";
          settings = {
            domain = "sync.example.test";
            guiClients = ["reader"];
            inherit listenAddress;
          };
        };
      }) ["0.0.0.0" "::" "[::]" "*" "10.1.0.1" "100.64.1.1"];
    syncthingLoopbackGUI = lib.all (listenAddress:
      success [
        machines
        {
          laplace.services.syncthing-server = {
            host = "alpha";
            settings = {
              domain = "sync.example.test";
              guiClients = ["reader"];
              inherit listenAddress;
            };
          };
        }
      ]) ["127.0.0.1" "localhost" "::1" "[::1]"];
    missingBrowser = rejected {services.miniflux = miniflux // {settings = miniflux.settings // {useKarakeepBrowser = true;};};};
    disabledBrowser = rejected {
      services = {
        miniflux = miniflux // {settings = miniflux.settings // {useKarakeepBrowser = true;};};
        karakeep = (app "read" "alpha") // {enable = false;};
      };
    };
    remoteBrowser = rejected {
      services = {
        miniflux = miniflux // {settings = miniflux.settings // {useKarakeepBrowser = true;};};
        karakeep = app "read" "beta";
      };
    };
    unknownEndpointWhenAbsent = rejected {tailnet.serviceGrants = [(grant {role = "reader";} "miniflux" "typo")];};
    unknownPrincipal = rejected {tailnet.serviceGrants = [(grant {role = "typo";} "miniflux" "https")];};
    ambiguousPrincipal = rejected {
      tailnet.serviceGrants = [
        (grant {
          role = "reader";
          node = "reader";
        } "miniflux" "https")
      ];
    };
    internalListenerNotExposed = rejected {
      services.miniflux = miniflux;
      tailnet.serviceGrants = [(grant {role = "reader";} "miniflux" "postgresql")];
    };
    duplicatePeerName = rejected {
      tailnet.peers.alpha = {
        ip = "100.64.2.1";
        ip6 = "fd7a:115c:a1e0::201";
        tags = [];
      };
    };
    duplicateAddress = rejected {
      tailnet.peers.duplicate = {
        ip = "100.64.1.1";
        ip6 = "fd7a:115c:a1e0::999";
        tags = [];
      };
    };
    reservedAdminGroup = rejected {tailnet.guests.admin.users = ["alice"];};
    restrictedForwarding = rejected {
      tailnet.peers.exit = {
        ip = "100.64.1.6";
        ip6 = "fd7a:115c:a1e0::106";
        tags = ["exit"];
      };
      tailnet.nodeFlows = [
        {
          from.role = "owner-device";
          to.role = "exit";
          ports = ["tcp/443"];
          forwarding = true;
        }
      ];
    };
    missingCaddyFacility = rejected {
      hosts.alpha.caddy = lib.mkForce false;
      services.silverbullet = silver;
    };
    unavailableDNSListener = rejected {
      hosts.beta.dnsListenerAvailable = lib.mkForce false;
      services.adguardhome = resolver;
    };
    domainConflict = rejected {
      services = {
        silverbullet = silver;
        vikunja = silver;
      };
    };
    staticDomainConflict = rejected {
      services.silverbullet = silver;
      tailnet.staticRecords = [
        {
          name = "notes.example.test";
          node = "reader";
          reason = "Fixture infrastructure";
        }
      ];
    };
    listenerConflict = rejected {
      services = {
        silverbullet = silver;
        vikunja = {
          host = "alpha";
          settings = {
            domain = "tasks.example.test";
            port = 8101;
          };
        };
      };
    };
    equivalentIPv6Listeners = lib.all (addresses:
      rejected (listenerPair (builtins.head addresses) (lib.last addresses))) [
      ["::1" "[::1]"]
      ["[::1]" "::1"]
      ["localhost" "[::1]"]
      ["::1" "0:0:0:0:0:0:0:0001"]
      ["fd00::a" "[FD00:0:0:0:0:0:0:000A]"]
      ["0:0:0:0:0:0:0:0" "fd00::1"]
      ["::ffff:192.0.2.1" "[0:0:0:0:0:FFFF:C000:201]"]
      ["fe80::a%eth0" "[FE80:0:0:0:0:0:0:A%eth0]"]
    ];
    distinctIPv6Listeners = success [machines {laplace = listenerPair "fd00::1" "[fd00::2]";}];
    ipv6ListenersOnDifferentPorts = success [
      machines
      {laplace = listenerPair "::1" "[::1]";}
      {laplace.services.vikunja.settings.port = lib.mkForce 8102;}
    ];
    distinctIPv6Scopes = success [machines {laplace = listenerPair "fe80::1%eth0" "[fe80::1%eth1]";}];
    stateConflict = rejected {
      services = {
        silverbullet = silver;
        altero = {
          host = "alpha";
          settings = {
            domain = "lib.example.test";
            dataDir = "/var/lib/silverbullet";
          };
        };
      };
    };
    gamePlacement = rejected {
      services.minecraft = {
        host = "desktop";
        settings = {
          domain = "mc.example.test";
          mapDomain = "map.example.test";
          sopsFile = "/fixture/game.yaml";
        };
      };
    };
    gameTrust = rejected {
      services.minecraft = {
        host = "alpha";
        settings = {
          domain = "mc.example.test";
          mapDomain = "map.example.test";
          sopsFile = "/fixture/game.yaml";
        };
      };
    };
    sameRecipeListenerConflict = rejected {
      services.minecraft = {
        host = "game";
        settings = {
          domain = "mc.example.test";
          mapDomain = "map.example.test";
          sopsFile = "/fixture/game.yaml";
          port = 443;
        };
      };
    };
    gameSourceCannotInheritTrust = rejected {
      services.miniflux = miniflux;
      tailnet.serviceGrants = [(grant {knownNodes = true;} "miniflux" "https")];
    };
    dnsMoves = lib.any (record: record.name == "rss.example.test" && record.value == "100.64.1.2") moved.network.dnsRecords;
    aliasesMoveBothFamilies = moved.network.aliases.service-miniflux-direct-v4 == "100.64.1.2/32" && moved.network.aliases.service-miniflux-direct-v6 == "fd7a:115c:a1e0::102/128";
    protocolPreserved = lib.any (c: c.owner == "miniflux" && c.ports == ["tcp/8087"] && c.destinationNodes == ["beta"]) moved.network.connections;
    sharedHTTPSIsNotIsolation = source.endpoints.miniflux.https.host == source.endpoints.silverbullet.https.host && source.endpoints.miniflux.https.port == source.endpoints.silverbullet.https.port;
    stopOnlyOwnsContributions = lib.all (c: c.owner != "miniflux") stopped.network.connections && lib.any (c: c.owner == "silverbullet") stopped.network.connections && !(stopped.network.aliases ? service-miniflux-direct-v4);
    guestMembershipUnions = stopped.network.groups.friends.members == ["alice" "bob"] && stopped.network.groups.family.members == ["alice"];
    knownNodesExcludesGuests = lib.all (c: c.guest != null || !(builtins.elem "*" c.sources)) source.network.connections;
    emptyPolicyIsExplicit = (model {}).network.rules == [] && (model {}).network.groups ? admin;
    previousHostStaysDeployable = moved.hosts.alpha.deployment.targetHost == "10.1.0.1";
  };
  inherit (builtins) attrNames attrValues;
in
  assert lib.asserts.assertMsg (lib.all (value: value) (attrValues checks))
  "cluster behavior failures: ${lib.concatStringsSep ", " (attrNames (lib.filterAttrs (_: value: !value) checks))}"; checks
