_: let
  server = {
    ip,
    trust,
    tailnet,
    storage ? [],
  }: {
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
        (server {
          ip = "10.0.20.83";
          trust = "trusted";
          tailnet = node "100.64.0.8" "fd7a:115c:a1e0::8" ["apps" "monitor" "infra" "rss" "sync"];
        })
        // {
          telemetry = true;
          beszel = "push";
          caddy = true;
        };
      mneme =
        (server {
          ip = "10.0.20.81";
          trust = "trusted";
          tailnet = node "100.64.0.6" "fd7a:115c:a1e0::6" ["photos" "infra"];
          storage = ["photos"];
        })
        // {
          telemetry = true;
          beszel = "push";
          caddy = true;
        };
      hermes =
        (server {
          ip = "10.0.20.82";
          trust = "trusted";
          tailnet = node "100.64.0.5" "fd7a:115c:a1e0::5" ["dns" "infra"];
        })
        // {
          telemetry = true;
          beszel = "push";
          caddy = true;
          dnsListenerAvailable = true;
        };
      argus =
        (server {
          ip = "10.0.20.84";
          trust = "trusted";
          tailnet = node "100.64.0.34" "fd7a:115c:a1e0::22" ["observability" "infra"];
          storage = ["observability-volumes"];
        })
        // {
          telemetry = true;
          caddy = true;
        };
      horos =
        (server {
          ip = "10.0.20.85";
          trust = "trusted";
          tailnet = node "100.64.0.35" "fd7a:115c:a1e0::23" ["notifications" "infra"];
        })
        // {
          telemetry = true;
          caddy = true;
        };
      apollo =
        (server {
          ip = "10.0.20.86";
          trust = "trusted";
          tailnet = node "100.64.0.41" "fd7a:115c:a1e0::29" ["media"];
          storage = ["media"];
        })
        // {caddy = true;};
      charon =
        (server {
          ip = "10.0.20.10";
          trust = "trusted";
          tailnet = node "100.64.0.3" "fd7a:115c:a1e0::3" ["exit"];
        })
        // {
          telemetry = true;
          beszel = "push";
        };
      loki =
        (server {
          ip = "10.0.60.2";
          trust = "game";
          tailnet = node "100.64.0.12" "fd7a:115c:a1e0::c" ["game"];
          storage = ["btrfs"];
        })
        // {
          telemetry = true;
          beszel = "pull";
          caddy = true;
        };
      hephaestus =
        (server {
          ip = "10.0.70.2";
          trust = "git";
          tailnet = null;
        })
        // {telemetry = true;};
      talos =
        (server {
          ip = "10.0.80.2";
          trust = "ci";
          tailnet = null;
        })
        // {telemetry = true;};
      bifrost =
        (server {
          ip = "10.0.50.2";
          trust = "control-plane";
          tailnet = null;
        })
        // {
          telemetry = true;
          beszel = "pull";
        };
      portunus =
        (server {
          ip = "10.0.40.2";
          trust = "edge";
          tailnet = null;
        })
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
      # External peers cannot host applications.
      peers = {
        nyx = node "100.64.0.42" "fd7a:115c:a1e0::2a" ["pve"];
        phone = node "100.64.0.40" "fd7a:115c:a1e0::28" ["phone" "owner-device" "sync"];
        device = node "100.64.0.7" "fd7a:115c:a1e0::7" ["phone"];
        kobo = node "100.64.0.38" "fd7a:115c:a1e0::26" ["reader"];
      };
      guests = {
        minecraft.users = [
          "tom"
          "olivia"
          "ash"
          "anika"
          "mary"
          "esther"
          "dini"
          "terrence"
          "zunaid"
          "lara"
          "kelly"
          "chris"
          "laura"
          "gayatri"
          "joel"
          "abiram"
        ];
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
