{
  lib,
  modules ? [./inventory.nix],
}: let
  inherit (lib) attrNames attrValues concatLists concatMap filter filterAttrs mapAttrs mapAttrsToList mkOption types unique;
  catalogue = import ./catalogue.nix {inherit lib;};
  evaluated = lib.evalModules {
    specialArgs = {inherit catalogue;};
    modules = [./schema.nix] ++ modules;
  };
  raw = evaluated.config.laplace;
  check = assertions: value: lib.asserts.checkAssertWarn assertions [] value;
  declared = filterAttrs (_: s: s != null) raw.services;
  hostExists = s: raw.hosts ? ${s.host};
  placementAssertions =
    mapAttrsToList (name: s: {
      assertion =
        hostExists s
        && raw.hosts.${s.host}.role == "server"
        && raw.hosts.${s.host}.deployment != null
        && raw.hosts.${s.host}.deployment.targetHost != null;
      message = "cluster service ${name}: host '${s.host}' must be a managed, deployable server (also for disabled declarations)";
    })
    declared;
  managedNodes = mapAttrs (_: h: h.tailnet) (filterAttrs (_: h: h.tailnet != null) raw.hosts);
  nodes = managedNodes // raw.tailnet.peers;
  uniqueField = values: builtins.length values == builtins.length (unique values);
  hostAssertions =
    [
      {
        assertion = lib.intersectLists (attrNames raw.hosts) (attrNames raw.tailnet.peers) == [];
        message = "cluster: external peer names overlap managed hosts";
      }
      {
        assertion = uniqueField (map (n: n.ip) (attrValues nodes));
        message = "cluster: duplicate Tailnet IPv4 addresses";
      }
      {
        assertion = uniqueField (map (n: n.ip6) (attrValues nodes));
        message = "cluster: duplicate Tailnet IPv6 addresses";
      }
      {
        assertion = uniqueField (filter (ip: ip != null) (map (h: h.lan.ip) (attrValues raw.hosts)));
        message = "cluster: duplicate managed LAN addresses";
      }
    ]
    ++ concatLists (mapAttrsToList (name: h: [
        {
          assertion = h.deployment == null || (h.role == "server" && h.deployment.targetHost != null && h.lan.ip != null);
          message = "cluster host ${name}: deployment requires an explicit server role and LAN target";
        }
        {
          assertion = h.trust != "game" || (h.tailnet != null && h.tailnet.tags == ["game"]);
          message = "cluster host ${name}: game isolation cannot inherit trusted node tags";
        }
      ])
      raw.hosts);
  # Copy source paths into the store with their dependency context. Derivations
  # already carry output context; never traverse their package-set passthru.
  dataOnly = value:
    if builtins.isPath value
    then "${value}"
    else if lib.isDerivation value
    then toString value
    else if builtins.isAttrs value
    then mapAttrs (_: dataOnly) value
    else if builtins.isList value
    then map dataOnly value
    else value;
  typed = let
    data = dataOnly raw;
  in
    builtins.deepSeq data (check (placementAssertions ++ hostAssertions) data);
  services = typed.services;
  activeServices = filterAttrs (_: s: s != null && s.enable) services;
  required = type: mkOption {inherit type;};
  option = type: default: mkOption {inherit type default;};
  endpointType = types.submodule ({config, ...}: {
    options = {
      host = required types.str;
      protocol = required (types.enum ["tcp" "udp"]);
      port = required types.port;
      endPort = option types.port config.port;
      listenAddress = required types.str;
      scope = required (types.enum ["loopback" "tailnet" "lan" "public"]);
      domain = option (types.nullOr types.str) null;
      publishDNS = option types.bool false;
      shared = option (types.nullOr types.str) null;
    };
  });
  resourceType = types.submodule {
    options = {
      kind = required (types.enum ["path" "uid" "database" "database-user" "database-version"]);
      value = required types.str;
      shared = option (types.nullOr types.str) null;
    };
  };
  metadata =
    (lib.evalModules {
      modules = [
        {
          options = {
            endpoints = option (types.attrsOf (types.attrsOf endpointType)) {};
            resources = option (types.attrsOf (types.listOf resourceType)) {};
          };
        }
        {
          endpoints = mapAttrs (name: instance:
            catalogue.${name}.endpoints {
              inherit instance;
              hosts = typed.hosts;
            }) (filterAttrs (_: s: s != null) services);
          resources = mapAttrs (name: instance: (catalogue.${name}.resources or (_: [])) instance) (filterAttrs (_: s: s != null) services);
        }
      ];
    }).config;
  declaredEndpoints = metadata.endpoints;
  endpoints = filterAttrs (name: _: activeServices ? ${name}) declaredEndpoints;
  endpointsList = concatLists (mapAttrsToList (service: es: mapAttrsToList (name: e: e // {inherit service name;}) es) endpoints);
  caddyHosts = unique (map (e: e.host) (filter (e: e.shared == "caddy") endpointsList));
  facilityEndpoints =
    concatMap (host: [
      {
        inherit host;
        service = "shared-caddy";
        name = "admin";
        protocol = "tcp";
        port = 2019;
        endPort = 2019;
        listenAddress = "localhost";
        shared = "caddy";
        domain = null;
      }
      {
        inherit host;
        service = "shared-caddy";
        name = "quic";
        protocol = "udp";
        port = 443;
        endPort = 443;
        listenAddress = "0.0.0.0";
        shared = "caddy";
        domain = null;
      }
    ])
    caddyHosts;
  resourcesList = concatLists (mapAttrsToList (service: rs:
    map (r:
      r
      // {
        inherit service;
        host = services.${service}.host;
      })
    rs) (filterAttrs (name: _: activeServices ? ${name}) metadata.resources));
  pairs = list: concatMap (a: map (b: {inherit a b;}) (filter (b: a.service < b.service) list)) list;
  listenerPairs = list:
    concatMap (a:
      map (b: {inherit a b;})
      (filter (b: "${a.service}/${a.name}/${a.host}" < "${b.service}/${b.name}/${b.host}") list))
    list;
  shared = a: b: a.shared != null && a.shared == b.shared;
  bindsOverlap = a: b:
    a.listenAddress
    == b.listenAddress
    || builtins.elem a.listenAddress ["0.0.0.0" "::" "[::]" "*"]
    || builtins.elem b.listenAddress ["0.0.0.0" "::" "[::]" "*"]
    || (builtins.elem a.listenAddress ["localhost" "127.0.0.1" "::1"] && builtins.elem b.listenAddress ["localhost" "127.0.0.1" "::1"]);
  endpointAssertions = concatLists (mapAttrsToList (s: es:
    mapAttrsToList (name: e: {
      assertion =
        typed.hosts ? ${e.host}
        && e.port <= e.endPort
        && builtins.elem name catalogue.${s}.endpointNames
        && (e.shared != "caddy" || typed.hosts.${e.host}.caddy);
      message = "cluster endpoint ${s}.${name}: invalid machine, interval, endpoint name or missing Caddy facility";
    })
    es)
  declaredEndpoints);
  conflicts =
    map ({
      a,
      b,
    }: {
      assertion =
        !(a.host
          == b.host
          && a.protocol == b.protocol
          && bindsOverlap a b
          && a.port <= b.endPort
          && b.port <= a.endPort
          && !(shared a b));
      message = "cluster listener conflict: ${a.service}.${a.name} and ${b.service}.${b.name} on ${a.host}";
    }) (listenerPairs (endpointsList ++ facilityEndpoints))
    ++ map ({
      a,
      b,
    }: {
      assertion = a.domain == null || b.domain == null || a.domain != b.domain;
      message = "cluster domain conflict: ${a.service} and ${b.service} both own ${toString a.domain}";
    }) (pairs endpointsList)
    ++ map ({
      a,
      b,
    }: let
      sameValue = a.value == b.value || (a.kind == "path" && (lib.hasPrefix "${a.value}/" b.value || lib.hasPrefix "${b.value}/" a.value));
      conflict =
        if a.kind == "database-version"
        then a.value != b.value
        else sameValue && !(shared a b);
    in {
      assertion = !(a.host == b.host && a.kind == b.kind && conflict);
      message = "cluster resource conflict: ${a.service} and ${b.service} (${a.kind}: ${a.value}, ${b.value}) on ${a.host}";
    }) (pairs resourcesList);
  recipeAssertions = concatLists (mapAttrsToList (
    name: instance:
      (catalogue.${name}.validate or (_: [])) {
        inherit instance;
        cluster = model;
      }
  ) (filterAttrs (_: s: s != null) services));
  consumerAssertions = concatLists (mapAttrsToList (name: host: [
      {
        assertion = !host.telemetry || activeServices ? observability;
        message = "cluster: telemetry writer ${name} requires enabled observability";
      }
      {
        assertion = host.beszel == null || activeServices ? beszel-hub;
        message = "cluster: Beszel agent ${name} requires enabled beszel-hub";
      }
    ])
    typed.hosts);
  network = import ./network.nix {
    inherit lib catalogue declaredEndpoints;
    cluster = model;
  };
  model =
    typed
    // {
      inherit activeServices endpoints nodes;
      inherit facilityEndpoints;
      network = network.data;
      resources = metadata.resources;
    };
  manifest = builtins.deepSeq typed (builtins.deepSeq metadata (check
    (endpointAssertions ++ recipeAssertions ++ consumerAssertions ++ conflicts ++ network.assertions)
    (builtins.deepSeq model model)));
  moduleFor = hostName: {
    imports =
      [
        ({config, ...}: {
          assertions =
            concatLists (mapAttrsToList (name: recipe:
              map (path: {
                assertion = lib.attrByPath path false config == (activeServices ? ${name} && activeServices.${name}.host == hostName);
                message = "cluster owns ${lib.showOption path} on ${hostName}; change laplace.services.${name} in the cluster, not the host";
              }) (recipe.activation or []))
            catalogue)
            ++ [
              {
                assertion = !(builtins.elem hostName caddyHosts) || config.laplace.services.caddy.enable;
                message = "cluster: ${hostName} declares application frontends but its Caddy facility is disabled";
              }
            ];
        })
        (import ./consumers.nix {
          cluster = manifest;
          inherit hostName;
        })
      ]
      ++ mapAttrsToList (name: instance:
        catalogue.${name}.project {
          inherit instance hostName;
          cluster = manifest;
        })
      activeServices;
  };
in
  builtins.seq manifest {
    inherit manifest;
    hostModule = hostName: builtins.seq manifest (moduleFor hostName);
  }
