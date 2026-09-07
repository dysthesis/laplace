# Tailnet nodes, role flows, and guest cohorts. Renderers filter this shared data by host.
_: {
  laplace.tailnet = {
    nodes = {
      hermes = {
        ip = "100.64.0.5";
        ip6 = "fd7a:115c:a1e0::5";
        tags = ["dns" "infra"];
      }; # AdGuard = tailnet resolver
      mneme = {
        ip = "100.64.0.6";
        ip6 = "fd7a:115c:a1e0::6";
        tags = ["photos" "infra"];
      }; # Immich
      mimir = {
        ip = "100.64.0.8";
        ip6 = "fd7a:115c:a1e0::8";
        tags = ["apps" "monitor" "infra" "rss" "sync"];
      }; # miniflux/altero/silverbullet/karakeep/vikunja/radicale/syncthing + beszel-hub
      apollo = {
        ip = "100.64.0.41";
        ip6 = "fd7a:115c:a1e0::29";
        tags = ["media"];
      }; # Prowlarr/Lidarr/qBittorrent/Navidrome
      argus = {
        ip = "100.64.0.34";
        ip6 = "fd7a:115c:a1e0::22";
        tags = ["observability" "infra"];
      }; # VictoriaMetrics/VictoriaLogs/Grafana
      horos = {
        ip = "100.64.0.35";
        ip6 = "fd7a:115c:a1e0::23";
        tags = ["notifications" "infra"];
      }; # Uptime Kuma/ntfy
      loki = {
        ip = "100.64.0.12";
        ip6 = "fd7a:115c:a1e0::c";
        tags = ["game"];
      }; # Minecraft (untrusted modpack)
      charon = {
        ip = "100.64.0.3";
        ip6 = "fd7a:115c:a1e0::3";
        tags = ["exit"];
      }; # exit node
      phobos = {
        ip = "100.64.0.1";
        ip6 = "fd7a:115c:a1e0::1";
        tags = ["workstation" "owner-device" "sync"];
      }; # workstation (laptop)
      deimos = {
        ip = "100.64.0.4";
        ip6 = "fd7a:115c:a1e0::4";
        tags = ["workstation" "owner-device" "sync"];
      }; # workstation (PC)
      phone = {
        ip = "100.64.0.40";
        ip6 = "fd7a:115c:a1e0::28";
        tags = ["phone" "owner-device" "sync"];
      }; # tag:phone (current mobile)
      device = {
        ip = "100.64.0.7";
        ip6 = "fd7a:115c:a1e0::7";
        tags = ["phone"];
      }; # retired phone
      kobo = {
        ip = "100.64.0.38";
        ip6 = "fd7a:115c:a1e0::26";
        tags = ["reader"];
      }; # e-reader; owner-only device, no services of its own
    };

    # Delete retired phones; keeping them preserves mesh access.
    flows = [
      {
        from = "owner-device";
        to = "owner-device";
        ports = ["*"];
      } # personal devices may initiate traffic to each other
      {
        from = "owner-device";
        to = "media";
        ports = ["tcp/443"];
      } # owner workstations and current phone -> music stack
      {
        from = "sync";
        to = "sync";
        ports = ["tcp/22000" "udp/22000"];
      } # Syncthing TCP/QUIC full mesh: laptop, PC, phone, and Mimir
      {
        from = "*";
        to = "dns";
        ports = ["udp/53" "tcp/53"];
      } # override_local_dns: all -> AdGuard
      {
        from = "infra";
        to = "monitor";
        ports = ["tcp/443"];
      } # beszel agents -> mimir hub (trusted hosts only; game is excluded)
      {
        from = "exit";
        to = "monitor";
        ports = ["tcp/443"];
      }
      {
        from = "workstation";
        to = "monitor";
        ports = ["tcp/443"];
      }
      {
        from = "workstation";
        to = "observability";
        ports = ["tcp/443"];
      }
      {
        from = "observability";
        to = "notifications";
        ports = ["tcp/443"];
      } # Alertmanager -> ntfy/Kuma heartbeat
      {
        from = "notifications";
        to = "observability";
        ports = ["tcp/443"];
      }
      {
        from = "notifications";
        to = "monitor";
        ports = ["tcp/443"];
      }
      {
        from = "notifications";
        to = "apps";
        ports = ["tcp/443"];
      }
      {
        from = "notifications";
        to = "photos";
        ports = ["tcp/443"];
      }
      {
        from = "notifications";
        to = "dns";
        ports = ["tcp/443"];
      }
      {
        from = "notifications";
        to = "game";
        ports = ["tcp/443" "tcp/25565"];
      }
      {
        from = "monitor";
        to = "game";
        ports = ["tcp/45876"];
      } # beszel hub pulls loki agent; no game -> monitor reverse path
      {
        from = "workstation";
        to = "apps";
        ports = ["tcp/443"];
      }
      {
        from = "workstation";
        to = "photos";
        ports = ["tcp/443"];
      }
      {
        from = "workstation";
        to = "dns";
        ports = ["tcp/443"];
      } # AdGuard UI
      {
        from = "workstation";
        to = "game";
        ports = ["tcp/25565" "udp/24454" "tcp/80" "tcp/443"];
      } # owner plays MC + fetches PackWiz bootstrap/source from PC/laptop
      {
        from = "workstation";
        to = "exit";
        ports = ["*"];
      } # exit-node egress
      {
        from = "workstation";
        to = "notifications";
        ports = ["tcp/443"];
      }
      {
        from = "workstation";
        to = "reader";
        ports = ["*"];
      } # ssh/rsync/http to the e-reader; it runs no gate of its own
      {
        from = "reader";
        to = "apps";
        ports = ["tcp/443"];
      } # karakeep
      {
        from = "reader";
        to = "rss";
        ports = [
          "tcp/443"
          "tcp/8087" # miniflux port
        ];
      } # miniflux
      {
        from = "phone";
        to = "apps";
        ports = ["*"];
      } # owner phones: full reach
      {
        from = "phone";
        to = "photos";
        ports = ["*"];
      }
      {
        from = "phone";
        to = "dns";
        ports = ["*"];
      }
      {
        from = "phone";
        to = "monitor";
        ports = ["*"];
      }
      {
        from = "phone";
        to = "observability";
        ports = ["tcp/443"];
      }
      {
        from = "phone";
        to = "notifications";
        ports = ["tcp/443"];
      }
      {
        from = "phone";
        to = "game";
        ports = ["*"];
      }
      {
        from = "phone";
        to = "exit";
        ports = ["*"];
      }
    ];

    guests = {
      minecraft = {
        users = [
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
        reach = {
          game = ["tcp/25565" "udp/24454" "tcp/80" "tcp/443"]; # Minecraft, voice chat, downloads, and map
          dns = ["udp/53"];
        };
      };

      miniflux = {
        users = ["mary"];
        reach = {rss = ["tcp/80" "tcp/443"];};
      };

      vikunja = {
        users = ["sheva"];
        reach = {
          apps = ["tcp/443"];
          dns = ["udp/53"];
        };
      };

      photos = {
        users = ["sheva"];
        reach = {
          photos = ["tcp/443"];
          dns = ["udp/53"];
        };
      };
    };
  };
}
