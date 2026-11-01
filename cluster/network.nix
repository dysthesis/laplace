{
  lib,
  cluster,
  catalogue,
  declaredEndpoints,
}: let
  inherit (lib) all any attrNames attrValues concatMap concatLists filter filterAttrs mapAttrs mapAttrsToList unique;
  inherit (cluster) nodes activeServices endpoints;
  cfg = cluster.tailnet;
  tags = unique (concatMap (n: n.tags) (attrValues nodes));
  selected = p:
    filter (key:
      if key == "knownNodes"
      then p.${key}
      else p.${key} != null) (attrNames p);
  principalValid = p:
    builtins.length (selected p)
    == 1
    && (p.role == null || builtins.elem p.role tags)
    && (p.node == null || nodes ? ${p.node})
    && (p.guest == null || cfg.guests ? ${p.guest})
    && (p.service
      == null
      || (catalogue ? ${p.service}
        && (!(activeServices ? ${p.service}) || nodes ? ${activeServices.${p.service}.host})));
  principalAssert = p: {
    assertion = principalValid p;
    message = "cluster policy: principal needs exactly one known role, guest, node, Tailnet source service, or knownNodes selector: ${builtins.toJSON p}";
  };
  selectNodes = p:
    if p.knownNodes
    then attrNames nodes
    else if p.role != null
    then attrNames (filterAttrs (_: n: builtins.elem p.role n.tags) nodes)
    else if p.node != null
    then [p.node]
    else if p.service != null && activeServices ? ${p.service}
    then lib.optional (nodes ? ${activeServices.${p.service}.host}) activeServices.${p.service}.host
    else [];
  aliasesFor = prefix: ["${prefix}-v4" "${prefix}-v6"];
  nodeAliases = name: aliasesFor "node-${name}";
  sourceTokens = p:
    if p.guest != null
    then ["group:${p.guest}"]
    else if p.knownNodes
    then map (tag: "tag:${tag}") tags
    else if p.role != null
    then ["tag:${p.role}"]
    else concatMap nodeAliases (selectNodes p);
  port = token:
    if token == "*"
    then "*"
    else builtins.elemAt (lib.splitString "/" token) 1;
  portsValid = ports:
    all (token:
      token
      == "*"
      || (let
        interval = map lib.toInt (lib.splitString "-" (port token));
        first = builtins.head interval;
        last = lib.last interval;
      in
        first > 0 && last <= 65535 && first <= last))
    ports;
  destinations = aliases: ports: concatMap (alias: map (p: "${alias}:${p}") (unique (map port ports))) aliases;
  activePrincipal = p: p.service == null || activeServices ? ${p.service};
  nodeConnections = map (flow: {
    owner = "node";
    sourceNodes = selectNodes flow.from;
    guest = flow.from.guest;
    destinationNodes = selectNodes flow.to;
    inherit (flow) ports forwarding;
    sources = sourceTokens flow.from;
    destinations =
      if flow.forwarding
      then ["autogroup:internet:*"]
      else destinations (concatMap nodeAliases (selectNodes flow.to)) flow.ports;
  }) (filter (flow: principalValid flow.from && principalValid flow.to && activePrincipal flow.from && activePrincipal flow.to) cfg.nodeFlows);
  endpointPrefix = service: endpoint: "service-${service}-${endpoint}";
  serviceConnections = map (grant: let
    e = endpoints.${grant.to.service}.${grant.to.endpoint};
    interval = toString e.port + lib.optionalString (e.endPort != e.port) "-${toString e.endPort}";
    ports = ["${e.protocol}/${interval}"];
  in {
    owner = grant.to.service;
    sourceNodes = selectNodes grant.from;
    guest = grant.from.guest;
    destinationNodes = [e.host];
    inherit ports;
    forwarding = false;
    sources = sourceTokens grant.from;
    destinations = destinations (aliasesFor (endpointPrefix grant.to.service grant.to.endpoint)) ports;
  }) (filter (g: principalValid g.from && activeServices ? ${g.to.service} && endpoints.${g.to.service} ? ${g.to.endpoint} && activePrincipal g.from) cfg.serviceGrants);
  connections = nodeConnections ++ serviceConnections;
  addressAliases = prefix: n: {
    "${prefix}-v4" = "${n.ip}/32";
    "${prefix}-v6" = "${n.ip6}/128";
  };
  aliases = lib.foldl' (a: b: a // b) {} (
    mapAttrsToList (name: n: addressAliases "node-${name}" n) nodes
    ++ concatLists (mapAttrsToList (service: es:
      mapAttrsToList (name: e:
        if nodes ? ${e.host} && e.scope == "tailnet"
        then addressAliases (endpointPrefix service name) nodes.${e.host}
        else {})
      es)
    endpoints)
  );
  appDNS = concatLists (mapAttrsToList (_: es:
    mapAttrsToList (_: e: {
      name = e.domain;
      type = "A";
      value = nodes.${e.host}.ip;
    }) (filterAttrs (_: e: e.publishDNS) es))
  endpoints);
  staticDNS =
    map (record: {
      inherit (record) name;
      type = "A";
      value = nodes.${record.node}.ip;
    })
    cfg.staticRecords;
  dnsRecords = unique (appDNS ++ staticDNS);
  # Use source and destination nodes, not service names, for this check.
  # Game nodes can use DNS, but not HTTPS, on the resolver.
  gameSafe = c:
    !any (n: builtins.elem "game" nodes.${n}.tags) c.sourceNodes
    || all (dest: builtins.elem "game" nodes.${dest}.tags) c.destinationNodes
    || (c.owner == "adguardhome" && all (p: builtins.elem p ["tcp/53" "udp/53"]) c.ports);
  assertions =
    [
      {
        assertion = !(cfg.guests ? admin);
        message = "cluster policy: guest group 'admin' is reserved for tag ownership";
      }
    ]
    ++ concatMap (f: [
      (principalAssert f.from)
      (principalAssert f.to)
      {
        assertion = f.to.guest == null;
        message = "cluster policy: node-flow destinations cannot be guest identities";
      }
      {
        assertion = portsValid f.ports;
        message = "cluster policy: invalid node-flow port interval";
      }
      {
        assertion = !f.forwarding || f.to.role == "exit";
        message = "cluster policy: forwarding grants must target the exit role";
      }
      {
        assertion = !f.forwarding || f.ports == ["*"];
        message = "cluster policy: exit forwarding supports only explicit wildcard ports; restricted ports must not broaden silently";
      }
    ])
    cfg.nodeFlows
    ++ concatMap (g: [
      (principalAssert g.from)
      {
        assertion = catalogue ? ${g.to.service} && builtins.elem g.to.endpoint catalogue.${g.to.service}.endpointNames;
        message = "cluster policy: unknown endpoint ${g.to.service}.${g.to.endpoint}";
      }
      {
        assertion =
          !(declaredEndpoints ? ${g.to.service})
          || (let
            e = declaredEndpoints.${g.to.service}.${g.to.endpoint} or null;
          in
            e != null && e.scope == "tailnet" && nodes ? ${e.host});
        message = "cluster policy: ${g.to.service}.${g.to.endpoint} is not a Tailnet endpoint; internal listeners are not implicitly exposed";
      }
    ])
    cfg.serviceGrants
    ++ map (r: {
      assertion = nodes ? ${r.node} && !(builtins.elem (lib.toLower r.name) (map (record: lib.toLower record.name) appDNS));
      message = "cluster DNS: static record ${r.name} has an unknown node or conflicts with an application-owned name";
    })
    cfg.staticRecords
    ++ concatLists (mapAttrsToList (s: es:
      mapAttrsToList (n: e: {
        assertion = !e.publishDNS || (e.domain != null && nodes ? ${e.host});
        message = "cluster DNS: ${s}.${n} requires a domain and an explicit Tailnet frontend address";
      })
      es)
    declaredEndpoints)
    ++ map (c: {
      assertion = gameSafe c;
      message = "cluster policy: game source reaches trusted destination through ${c.owner} grant";
    })
    connections;
in {
  inherit assertions;
  data = {
    inherit aliases connections dnsRecords;
    rules = map (c: {
      src = c.sources;
      dst = c.destinations;
    }) (filter (c: c.sources != [] && c.destinations != []) connections);
    tagOwners = lib.genAttrs (map (t: "tag:${t}") tags) (_: ["group:admin"]);
    groups =
      {
        admin = {
          members = ["demiurge"];
          destinations = [];
        };
      }
      // mapAttrs (_: g: {
        members = g.users;
        destinations = [];
      })
      cfg.guests;
  };
}
