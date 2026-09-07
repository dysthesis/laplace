# Tailnet-only music automation guest. Caddy is the sole web ingress.
{
  config,
  lib,
  pkgs,
  ...
}: let
  musicHost = "music.dysthesis.com";
  downloadsDir = "/srv/media/downloads";
  slskdDownloadsDir = "${downloadsDir}/soulseek";
  soularrStateDir = "/var/lib/soularr";
  musicDir = "/srv/media/music";
  qbitProfileDir = "/var/lib/qBittorrent";
  qbitConfig = "${qbitProfileDir}/qBittorrent/config/qBittorrent.conf";
  qbitInitialConfig = pkgs.writeText "qbittorrent-initial.conf" ''
    [BitTorrent]
    Session\DefaultSavePath=${downloadsDir}/

    [Preferences]
    WebUI\Address=127.0.0.1
    WebUI\AuthSubnetWhitelistEnabled=false
    WebUI\ClickjackingProtection=true
    WebUI\CSRFProtection=true
    WebUI\HostHeaderValidation=true
    WebUI\LocalHostAuth=false
    WebUI\ReverseProxySupportEnabled=true
    WebUI\SecureCookie=true
    WebUI\ServerDomains=${musicHost}
    WebUI\TrustedReverseProxiesList=127.0.0.1;::1
    WebUI\UseUPnP=false
  '';
  soularrConfig = pkgs.writeTextDir "config.ini" ''
    [Lidarr]
    api_key = ''${LIDARR_API_KEY}
    host_url = http://127.0.0.1:8686/lidarr
    download_dir = ${slskdDownloadsDir}
    disable_sync = False

    [Slskd]
    api_key = ''${SLSKD_API_KEY}
    host_url = http://127.0.0.1:5030
    url_base = /slskd
    download_dir = ${slskdDownloadsDir}
    delete_searches = False
    stalled_timeout = 3600
    remote_queue_timeout = 300

    [Release Settings]
    use_selected_lidarr_release = False
    use_most_common_tracknum = True
    allow_multi_disc = True
    accepted_countries = Europe,Japan,United Kingdom,United States,[Worldwide],Australia,Canada
    skip_region_check = False
    accepted_formats = CD,Digital Media,Vinyl

    [Search Settings]
    search_timeout = 5000
    maximum_peer_queue = 50
    minimum_peer_upload_speed = 0
    minimum_filename_match_ratio = 0.8
    minimum_search_interval = 5
    allowed_filetypes = flac 24/192,flac 16/44.1,flac,mp3 320,mp3
    ignored_users =
    album_prepend_artist = False
    search_type = incrementing_page
    number_of_albums_to_grab = 10
    title_blacklist =
    search_blacklist =
    search_source = missing
    failed_import_denylist = True

    [Download Settings]
    download_filtering = True
    use_extension_whitelist = False
    extensions_whitelist = lrc,nfo,txt
    rename_download_folders = True

    [Logging]
    level = INFO
    format = [%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s
    datefmt = %Y-%m-%dT%H:%M:%S%z
    log_to_file = False
  '';
  soularrLauncher = pkgs.writeText "soularr-launcher.py" ''
    import os
    import xml.etree.ElementTree as ET

    lidarr_config = ET.parse("${config.services.lidarr.dataDir}/config.xml").getroot()
    lidarr_api_key = lidarr_config.findtext("ApiKey", "").strip()
    if not lidarr_api_key:
        raise SystemExit("Lidarr config.xml has no API key")

    os.environ["LIDARR_API_KEY"] = lidarr_api_key
    os.execve(
        "${pkgs.soularr}/bin/soularr",
        [
            "soularr",
            "--config-dir",
            "${soularrConfig}",
            "--var-dir",
            "${soularrStateDir}",
        ],
        os.environ,
    )
  '';
  servarrHardening = {
    CapabilityBoundingSet = "";
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "full";
    RemoveIPC = true;
    RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK"];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
  };
in {
  sops = {
    secrets = {
      soulseek_username.sopsFile = ../../system/secrets/apollo.yaml;
      soulseek_password.sopsFile = ../../system/secrets/apollo.yaml;
      slskd_api_key.sopsFile = ../../system/secrets/apollo.yaml;
      slskd_web_password.sopsFile = ../../system/secrets/apollo.yaml;
    };
    templates = {
      "slskd.env" = {
        owner = "slskd";
        group = "media-downloads";
        restartUnits = ["slskd.service"];
        content = ''
          SLSKD_SLSK_USERNAME=${config.sops.placeholder.soulseek_username}
          SLSKD_SLSK_PASSWORD=${config.sops.placeholder.soulseek_password}
          SLSKD_USERNAME=apollo
          SLSKD_PASSWORD=${config.sops.placeholder.slskd_web_password}
          SLSKD_API_KEY=role=Administrator;cidr=127.0.0.1/32,::1/128;${config.sops.placeholder.slskd_api_key}
        '';
      };
      "soularr.env" = {
        owner = "lidarr";
        group = "navidrome";
        content = "SLSKD_API_KEY=${config.sops.placeholder.slskd_api_key}";
      };
    };
  };

  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.86/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4;
      memory = 4096; # MiB, Lidarr imports and Navidrome transcoding burst
      balloon = 2048; # MiB, enough for the six idle daemons without swap churn
      diskSize = "256G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
      polkit.enable = true;
      firewall.enable = true;
      fail2ban.enable = true;
    };

    zram.enable = true;

    services = {
      tailscale.enable = true;
      caddy = {
        enable = true;
        email = "dysthesis@protonmail.com";
        openFirewall = false; # nftables admits :443 only from authorised tailnet identities
        cloudflare = {
          enable = true;
          sopsFile = ../../system/secrets/apollo.yaml;
        };
        virtualHosts.${musicHost} = {
          # Service URLs can contain API keys; do not retain request URIs.
          logFormat = null;
          extraConfig = ''
            tls {
              dns cloudflare {env.CF_API_TOKEN}
              resolvers 1.1.1.1
            }

            header {
              -Server
              Strict-Transport-Security "max-age=31536000"
              X-Content-Type-Options "nosniff"
            }

            @notSSE not header Accept *text/event-stream*
            encode @notSSE

            route {
              redir /prowlarr /prowlarr/ 308
              redir /lidarr /lidarr/ 308
              redir /slskd /slskd/ 308
              redir /qbittorrent /qbittorrent/ 308

              handle /prowlarr/* {
                reverse_proxy 127.0.0.1:9696
              }
              handle /lidarr/* {
                reverse_proxy 127.0.0.1:8686
              }
              handle /slskd/* {
                reverse_proxy 127.0.0.1:5030
              }
              # qBittorrent has no URL-base setting; strip only its external prefix.
              handle_path /qbittorrent/* {
                reverse_proxy 127.0.0.1:8080
              }
              handle {
                reverse_proxy 127.0.0.1:4533
              }
            }
          '';
        };
      };
    };
  };

  services = {
    flaresolverr = {
      enable = true;
      openFirewall = false;
    };

    prowlarr = {
      enable = true;
      openFirewall = false;
      settings = {
        # auth = {
        #   method = "Forms";
        #   required = "Enabled";
        #   trustCgnatIpAddresses = false;
        # };
        server = {
          bindaddress = "127.0.0.1";
          port = 9696;
          urlbase = "/prowlarr";
        };
      };
    };

    lidarr = {
      enable = true;
      group = "navidrome"; # imported music is read-only to the Navidrome service
      openFirewall = false;
      settings = {
        auth = {
          method = "Forms";
          required = "Enabled";
          trustCgnatIpAddresses = false;
        };
        server = {
          bindaddress = "127.0.0.1";
          port = 8686;
          urlbase = "/lidarr";
        };
      };
    };

    slskd = {
      enable = true;
      group = "media-downloads";
      environmentFile = config.sops.templates."slskd.env".path;
      openFirewall = false;
      settings = {
        directories = {
          downloads = slskdDownloadsDir;
          incomplete = "${slskdDownloadsDir}/incomplete";
        };
        shares = {
          directories = [];
          filters = [];
        };
        soulseek = {
          listen_ip_address = "0.0.0.0";
          listen_port = 50300;
        };
        web = {
          ip_address = "127.0.0.1";
          port = 5030;
          url_base = "/slskd";
          https.disabled = true;
          authentication.disabled = false;
        };
      };
    };

    qbittorrent = {
      enable = true;
      extraArgs = ["--confirm-legal-notice"];
      group = "media-downloads";
      openFirewall = false;
      profileDir = qbitProfileDir;
      webuiPort = 8080;
    };

    navidrome = {
      enable = true;
      openFirewall = false;
      settings = {
        Address = "127.0.0.1";
        BaseUrl = "https://${musicHost}";
        EnableInsightsCollector = false;
        MusicFolder = musicDir;
        Port = 4533;
      };
    };
  };

  users = {
    groups.media-downloads = {};
    users.lidarr.extraGroups = ["media-downloads"];
  };

  systemd = {
    services = {
      flaresolverr.environment = {
        HOST = "127.0.0.1";
        LOG_LEVEL = "warning";
      };
      lidarr.serviceConfig =
        servarrHardening
        // {
          ReadWritePaths = [config.services.lidarr.dataDir downloadsDir musicDir];
          SupplementaryGroups = ["media-downloads"];
          UMask = "0027";
        };
      slskd = {
        requires = ["slskd-prepare.service"];
        after = ["slskd-prepare.service"];
        serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "5s";
          UMask = "0007";
        };
      };
      slskd-prepare = {
        description = "Prepare slskd download directories";
        before = ["slskd.service"];
        unitConfig.RequiresMountsFor = downloadsDir;
        serviceConfig.Type = "oneshot";
        script = ''
          ${pkgs.coreutils}/bin/test -d ${lib.escapeShellArg downloadsDir}
          ${pkgs.coreutils}/bin/install -d -m 2770 -o slskd -g media-downloads \
            ${lib.escapeShellArg slskdDownloadsDir} \
            ${lib.escapeShellArg "${slskdDownloadsDir}/incomplete"}
        '';
      };
      soularr = {
        description = "Download Lidarr wanted albums from Soulseek";
        requires = ["lidarr.service" "slskd.service"];
        after = ["lidarr.service" "slskd.service"];
        unitConfig.ConditionPathExists = "${config.services.lidarr.dataDir}/config.xml";
        serviceConfig =
          servarrHardening
          // {
            Type = "oneshot";
            User = "lidarr";
            Group = "navidrome";
            SupplementaryGroups = ["media-downloads"];
            StateDirectory = "soularr";
            StateDirectoryMode = "0750";
            WorkingDirectory = soularrStateDir;
            EnvironmentFile = config.sops.templates."soularr.env".path;
            ExecStart = "${pkgs.python3}/bin/python ${soularrLauncher}";
            ProtectSystem = "strict";
            ReadWritePaths = [soularrStateDir slskdDownloadsDir];
            TimeoutStartSec = "2h";
            UMask = "0027";
          };
      };
      prowlarr.serviceConfig =
        servarrHardening
        // {
          UMask = "0077";
        };
      qbittorrent = {
        # Seed secure proxy/storage defaults once; keep the generated password and
        # subsequent WebUI changes in the persisted mutable profile.
        preStart = lib.mkBefore ''
          if [ ! -s ${lib.escapeShellArg qbitConfig} ]; then
            ${pkgs.coreutils}/bin/install -m 0600 ${qbitInitialConfig} ${lib.escapeShellArg qbitConfig}
          fi
        '';
        serviceConfig.UMask = "0027";
      };
    };
    timers.soularr = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitInactiveSec = "5m";
      };
    };

    tmpfiles.settings = {
      "10-apollo-media" = {
        "/srv/media".d = {
          mode = "0751";
          user = "root";
          group = "root";
        };
        ${downloadsDir}.d = {
          mode = "2770";
          user = "qbittorrent";
          group = "media-downloads";
        };
      };
      # Override Navidrome's create-only defaults: Lidarr writes; Navidrome reads.
      navidromeDirs.${musicDir}.d = {
        mode = lib.mkForce "2750";
        user = lib.mkForce "lidarr";
        group = lib.mkForce "navidrome";
      };
    };
  };

  mnemosyne.dirs = [
    "/var/lib/private/prowlarr"
    "/var/lib/lidarr"
    "/var/lib/slskd"
    soularrStateDir
    qbitProfileDir
    "/var/lib/navidrome"
    "/srv/media"
  ];

  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
