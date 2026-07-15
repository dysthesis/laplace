{
  config,
  pkgs,
  ...
}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.20.1"];
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.20.84/24";
      Gateway = "10.0.20.1";
      DNS = "10.0.20.1";
      DHCP = "no";
    };
  };

  # PVE attaches one 128 GiB virtio disk with backup=0. Its two ext4 partitions
  # are labelled by the provisioning runbook in docs/observability.md.
  fileSystems = {
    "/var/lib/private/victoriametrics" = {
      device = "/dev/disk/by-label/argus-metrics";
      fsType = "ext4";
      options = ["nofail" "noatime" "x-systemd.device-timeout=10s"];
    };
    "/var/lib/private/victorialogs" = {
      device = "/dev/disk/by-label/argus-logs";
      fsType = "ext4";
      options = ["nofail" "noatime" "x-systemd.device-timeout=10s"];
    };
  };

  laplace = {
    profiles = ["proxmox"];
    harden = ["malloc" "kernel"];
    proxmox = {
      cores = 4;
      memory = 6144;
      balloon = 4096;
      diskSize = "32G";
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
      observability = {
        enable = true;
        expectedHosts = ["argus" "talos" "mneme" "mimir" "horos" "hermes" "charon" "loki" "hephaestus" "bifrost" "portunus"];
        frontend = {
          enable = true;
          cloudflareSopsFile = ../../system/secrets/argus.yaml;
        };
        ingress = {
          enable = true;
          caFile = config.sops.secrets.telemetry_ingress_client_ca.path;
          writers = {
            talos = {
              sourceAddress = "10.0.80.2";
              certificateFile = config.sops.secrets.telemetry_talos_client_certificate.path;
              certificateFingerprint = "bf7e47c79f283095d5c4675c8fbdf9be9e8b57c806a2e0583b9820cab1397034";
              role = "ci-runner";
              metricsPort = 8430;
            };
            mneme = {
              sourceAddress = "10.0.20.81";
              certificateFile = config.sops.secrets.telemetry_mneme_client_certificate.path;
              certificateFingerprint = "5510a6938727d9b1360f6481b915359a3ad028f486cedeae917ab3302d87d9bd";
              role = "photos";
              metricsPort = 8431;
            };
            mimir = {
              sourceAddress = "10.0.20.83";
              certificateFile = config.sops.secrets.telemetry_mimir_client_certificate.path;
              certificateFingerprint = "fa7365b4e32067bb3cda4bf091d8da397a01092b43c30ed2398f67d17e035d12";
              role = "apps";
              metricsPort = 8432;
            };
            horos = {
              sourceAddress = "10.0.20.85";
              certificateFile = config.sops.secrets.telemetry_horos_client_certificate.path;
              certificateFingerprint = "7bd259022b7440a589a27716fbb4008b64686d66f71070a64311eb3e27a64f41";
              role = "notifications";
              metricsPort = 8433;
            };
            hermes = {
              sourceAddress = "10.0.20.82";
              certificateFile = config.sops.secrets.telemetry_hermes_client_certificate.path;
              certificateFingerprint = "44efa91be270f0179d193cd3913c881d55dda8c783c89377f409425325bf4385";
              role = "dns";
              metricsPort = 8434;
            };
            charon = {
              sourceAddress = "10.0.20.10";
              certificateFile = config.sops.secrets.telemetry_charon_client_certificate.path;
              certificateFingerprint = "566364714879f02173145d77b35b329d1602f91bb5333a919bf676ca26e540d8";
              role = "exit";
              metricsPort = 8435;
            };
            loki = {
              sourceAddress = "10.0.60.2";
              certificateFile = config.sops.secrets.telemetry_loki_client_certificate.path;
              certificateFingerprint = "e7c59c344159615ee66e3afb583aaf59d38a370413e078e2402311e9fd711bed";
              role = "game";
              metricsPort = 8436;
            };
            hephaestus = {
              sourceAddress = "10.0.70.2";
              certificateFile = config.sops.secrets.telemetry_hephaestus_client_certificate.path;
              certificateFingerprint = "9c254f686ca1fb96b6cc82e4216a5484df9f0808d96a2795095c1ac3e3695431";
              role = "git";
              metricsPort = 8437;
            };
            bifrost = {
              sourceAddress = "10.0.50.2";
              certificateFile = config.sops.secrets.telemetry_bifrost_client_certificate.path;
              certificateFingerprint = "6ca0915346fdccfb656c6501bdcde1de53c7b94a69b9e5f8a84e9876498346ad";
              role = "control-plane";
              metricsPort = 8438;
            };
            portunus = {
              sourceAddress = "10.0.40.2";
              certificateFile = config.sops.secrets.telemetry_portunus_client_certificate.path;
              certificateFingerprint = "1aae3ff3d3c81f9c89bee547f00ce27348ceada96eeef5337564a7eeebc01a45";
              role = "edge";
              metricsPort = 8439;
            };
          };
        };
      };
      telemetry = {
        enable = true;
        role = "observability";
        metrics.remoteWriteUrl = "http://127.0.0.1:8428/api/v1/write";
        journal.url = "http://127.0.0.1:9428/insert/journald";
      };
    };
  };

  sops.secrets = {
    ntfy_alertmanager_token = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["alertmanager.service"];
    };
    uptime_kuma_push_url = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["alertmanager.service"];
    };
    telemetry_ingress_client_ca = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_talos_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_mneme_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_mimir_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_horos_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_hermes_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_charon_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_loki_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_hephaestus_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_bifrost_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
    telemetry_portunus_client_certificate = {
      sopsFile = ../../system/secrets/argus.yaml;
      restartUnits = ["caddy.service"];
    };
  };
  sops.templates."alertmanager.env".content = ''
    NTFY_ALERTMANAGER_TOKEN=${config.sops.placeholder.ntfy_alertmanager_token}
    UPTIME_KUMA_PUSH_URL=${config.sops.placeholder.uptime_kuma_push_url}
  '';
  services.prometheus.alertmanager.environmentFile = config.sops.templates."alertmanager.env".path;

  environment.systemPackages = with pkgs; [git vim];
}
