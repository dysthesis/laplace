# Forgejo Actions runner host, running as a Proxmox guest. Everything generic
# to a Proxmox VM lives in the `proxmox` profile; this module only declares what
# is specific to this guest.
#
# talos (the bronze automaton Hephaestus forged — it runs the forge's jobs) is
# the runner module's intended end-state: CI executes semi-arbitrary code, so it
# gets its own VLAN80 (10.0.80.2) blast radius instead of sharing hephaestus
# with Forgejo + Postgres. It dials Forgejo directly at 10.0.70.2:8080 across a
# VLAN80->VLAN70 pinhole (OPNsense must pass it; hephaestus's firewall accepts
# it) — NOT via git.dysthesis.com, which resolves to the WAN edge, sits behind
# Anubis, and would need NAT reflection. The registered address is also what
# jobs clone from, so it must stay reachable from this VLAN.
{
  config,
  pkgs,
  ...
}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.80.1"];
    hosts."10.0.20.84" = ["telemetry.dysthesis.com"];
    # nftables backend so the proxmox profile's :22 scoping (VLAN20-only)
    # actually applies — it is a silent no-op on the iptables backend. talos has
    # no tailscale (which would flip this on) and no Docker, so set it explicitly.
    nftables.enable = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.80.2/24";
      Gateway = "10.0.80.1";
      DNS = "10.0.80.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    harden = ["malloc" "kernel"];
    proxmox = {
      cores = 4;
      memory = 6144; # MiB, ballooning ceiling (nix evals/builds burst)
      balloon = 6144; # MiB, fixed allocation required by representative Nix CI
      # simplification: 64G is a guess — the store grows with every CI build and
      # nothing GCs it yet. Upgrade path: nix.gc.automatic or a bigger disk once
      # `df` on real CI load says so.
      diskSize = "64G";
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
      polkit.enable = true;
      firewall.enable = true;
      fail2ban.enable = true;
    };

    zram.enable = true;

    # Remote Forgejo (server stays on hephaestus). A fresh registration token is
    # needed for the move anyway — the persisted .runner identity does not
    # migrate. Workflows say `runs-on: nix`, so they don't change.
    services = {
      forgejo-runner = {
        enable = true;
        url = "http://10.0.70.2:8080";
        tokenFile = config.sops.secrets.action_runner.path;
      };
      telemetry = {
        enable = true;
        role = "ci-runner";
        metrics = {
          remoteWriteUrl = "https://telemetry.dysthesis.com:8443/talos/metrics";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
        journal = {
          url = "https://telemetry.dysthesis.com:8444/talos/journald";
          certificateFile = config.sops.secrets.telemetry_client_certificate.path;
          keyFile = config.sops.secrets.telemetry_client_key.path;
        };
      };
    };
  };

  # Runner registration creds (TOKEN env line), sops-encrypted to this host's
  # age key. Secret wiring is inherently per-host (sops-nix per-host age key);
  # the runner logic itself lives in system/services/forgejo-runner.
  sops.secrets = {
    action_runner.sopsFile = ../../system/secrets/talos.yaml;
    telemetry_client_certificate = {
      sopsFile = ../../system/secrets/talos.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
    telemetry_client_key = {
      sopsFile = ../../system/secrets/talos.yaml;
      restartUnits = ["vmagent.service" "systemd-journal-upload.service"];
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
  ];
}
