{lib, ...}: let
  role = name: {role = name;};
  service = name: {service = name;};
  guest = name: {guest = name;};
  grants = from: target: endpoints:
    map (endpoint: {
      inherit from;
      to = {
        service = target;
        inherit endpoint;
      };
    })
    endpoints;
  https = from: targets: lib.concatMap (target: grants from target ["https"]) targets;
  applications = ["miniflux" "altero" "silverbullet" "vikunja" "radicale" "karakeep" "syncthing-server" "livesync"];
  flow = from: to: ports: {inherit from to ports;};
in {
  laplace.tailnet = {
    # These permissions are intentionally machine-bound. In particular, the
    # legacy phone full-node exceptions do not move with any application.
    nodeFlows =
      [
        (flow (role "owner-device") (role "owner-device") ["*"])
        (flow (role "sync") (role "sync") ["tcp/22000" "udp/22000"])
        ((flow (role "workstation") (role "exit") ["*"]) // {forwarding = true;})
        (flow (role "workstation") (role "pve") ["*"])
        (flow (role "workstation") (role "reader") ["*"])
        (flow (service "beszel-hub") {node = "loki";} ["tcp/45876"])
      ]
      ++ map (target: flow (role "phone") (role target) ["*"]) ["apps" "photos" "dns" "monitor" "game"]
      ++ [((flow (role "phone") (role "exit") ["*"]) // {forwarding = true;})];
    serviceGrants =
      https (role "owner-device") ["music"]
      ++ grants {knownNodes = true;} "adguardhome" ["dns" "dns-tcp"]
      ++ lib.concatMap (source: https (role source) ["beszel-hub"]) ["infra" "exit" "workstation"]
      ++ https (role "workstation") (["observability" "immich" "adguardhome" "uptime-kuma" "ntfy"] ++ applications)
      ++ grants (role "workstation") "minecraft" ["game" "voice" "http" "https"]
      ++ https (service "observability") ["ntfy" "uptime-kuma"]
      ++ https (service "uptime-kuma") (["observability" "beszel-hub" "immich" "adguardhome"] ++ applications)
      ++ grants (service "uptime-kuma") "minecraft" ["https" "game"]
      ++ https (role "reader") ["karakeep" "miniflux"]
      ++ grants (role "reader") "miniflux" ["direct"]
      ++ https (role "phone") ["observability" "uptime-kuma" "ntfy"]
      ++ grants (role "sync") "syncthing-server" ["transfer" "transfer-quic"]
      ++ grants (guest "minecraft") "minecraft" ["game" "voice" "http" "https"]
      ++ grants (guest "minecraft") "adguardhome" ["dns"]
      ++ grants (guest "miniflux") "miniflux" ["http" "https"]
      ++ https (guest "vikunja") ["vikunja"]
      ++ grants (guest "vikunja") "adguardhome" ["dns"]
      ++ https (guest "photos") ["immich"]
      ++ grants (guest "photos") "adguardhome" ["dns"];
  };
}
