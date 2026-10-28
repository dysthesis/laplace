_: let
  server = ip: trust: tailnet: storage: {
    system = "x86_64-linux";
    role = "server";
    lan.ip = ip;
    deployment = {};
    inherit trust tailnet;
    storage = ["persistent"] ++ storage;
  };
  node = ip: ip6: tags: {inherit ip ip6 tags;};
  workstation = tailnet: {
    system = "x86_64-linux";
    role = "workstation";
    trust = "client";
    inherit tailnet;
  };
in {
  laplace = {
    hosts = {
      mimir =
        (server "10.0.20.83" "trusted" (node "100.64.0.8" "fd7a:115c:a1e0::8" ["apps" "monitor" "infra" "rss" "sync"]) [])
        // {
          telemetry = true;
          beszel = "push";
          caddy = true;
        };
      mneme =
        (server "10.0.20.81" "trusted" (node "100.64.0.6" "fd7a:115c:a1e0::6" ["photos" "infra"]) ["photos"])
        // {
          telemetry = true;
          beszel = "push";
          caddy = true;
        };
      hermes =
        (server "10.0.20.82" "trusted" (node "100.64.0.5" "fd7a:115c:a1e0::5" ["dns" "infra"]) [])
        // {
          telemetry = true;
          beszel = "push";
          caddy = true;
          dnsListenerAvailable = true;
        };
      argus =
        (server "10.0.20.84" "trusted" (node "100.64.0.34" "fd7a:115c:a1e0::22" ["observability" "infra"]) ["observability-volumes"])
        // {
          telemetry = true;
          caddy = true;
        };
      horos =
        (server "10.0.20.85" "trusted" (node "100.64.0.35" "fd7a:115c:a1e0::23" ["notifications" "infra"]) [])
        // {
          telemetry = true;
          caddy = true;
        };
      apollo = (server "10.0.20.86" "trusted" (node "100.64.0.41" "fd7a:115c:a1e0::29" ["media"]) ["media"]) // {caddy = true;};
      charon =
        (server "10.0.20.10" "trusted" (node "100.64.0.3" "fd7a:115c:a1e0::3" ["exit"]) [])
        // {
          telemetry = true;
          beszel = "push";
        };
      loki =
        (server "10.0.60.2" "game" (node "100.64.0.12" "fd7a:115c:a1e0::c" ["game"]) ["btrfs"])
        // {
          telemetry = true;
          beszel = "pull";
          caddy = true;
        };
      hephaestus = (server "10.0.70.2" "git" null []) // {telemetry = true;};
      talos = (server "10.0.80.2" "ci" null []) // {telemetry = true;};
      bifrost =
        (server "10.0.50.2" "control-plane" null [])
        // {
          telemetry = true;
          beszel = "pull";
        };
      portunus =
        (server "10.0.40.2" "edge" null [])
        // {
          telemetry = true;
          beszel = "pull";
          caddy = true;
        };
      deimos = workstation (node "100.64.0.4" "fd7a:115c:a1e0::4" ["workstation" "owner-device" "sync"]);
      phobos = workstation (node "100.64.0.1" "fd7a:115c:a1e0::1" ["workstation" "owner-device" "sync"]);
      chaos = {
        system = "x86_64-linux";
        role = "installer";
        trust = "client";
      };
    };
    tailnet = {
      # External identities are never application placement candidates.
      peers = {
        nyx = node "100.64.0.42" "fd7a:115c:a1e0::2a" ["pve"];
        phone = node "100.64.0.40" "fd7a:115c:a1e0::28" ["phone" "owner-device" "sync"];
        device = node "100.64.0.7" "fd7a:115c:a1e0::7" ["phone"];
        kobo = node "100.64.0.38" "fd7a:115c:a1e0::26" ["reader"];
      };
      guests = {
        minecraft.users = ["tom" "olivia" "ash" "anika" "mary" "esther" "dini" "terrence" "zunaid" "lara" "kelly" "chris" "laura" "gayatri" "joel" "abiram"];
        miniflux.users = ["mary"];
        vikunja.users = ["sheva"];
        photos.users = ["sheva"];
      };
      staticRecords = [
        {
          name = "topos.dysthesis.com";
          node = "mimir";
          reason = "Unestablished external consumer; AFFiNE is not deployed.";
        }
        {
          name = "nyx.dysthesis.com";
          node = "nyx";
          reason = "Unmanaged Proxmox management identity, not an application.";
        }
      ];
    };
  };
}
