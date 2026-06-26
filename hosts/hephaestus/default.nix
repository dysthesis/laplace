# Forgejo host, running as a Proxmox guest. Everything generic to a Proxmox VM
# (disk layout, impermanence, bootloader, virtio, serial, qemuGuest, the archon
# admin user, the VMA image artifact) lives in the `proxmox` profile; this module
# only declares what is specific to this guest.
#
# hephaestus lives on its own VLAN70 (10.0.70.2). Forgejo serves plain HTTP on
# :8080; TLS terminates at the edge on portunus (10.0.40.2, DMZ), which reverse-
# proxies git.dysthesis.com across a single VLAN40->VLAN70 pinhole — the same
# split bifrost/headscale use. So :8080 is opened ONLY to portunus.
{
  config,
  pkgs,
  ...
}: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["127.0.0.1" "10.0.70.1"];
    # nftables backend so the scoped :8080 rule (extraInputRules) actually applies
    # — it is a silent no-op on the iptables backend. hephaestus has no tailscale
    # (which would flip this on) and no Docker, so set it explicitly. The proxmox
    # profile's :22 scoping (VLAN20-only) is likewise gated on this.
    nftables.enable = true;
    # portunus (10.0.40.2) is the only host that proxies to Forgejo's HTTP port.
    # OPNsense must also pass VLAN40 (10.0.40.2) -> 10.0.70.2:<HTTP_PORT>.
    firewall.extraInputRules = ''
      ip saddr 10.0.40.2/32 tcp dport ${toString config.services.forgejo.settings.server.HTTP_PORT} accept
    '';
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.70.2/24";
      Gateway = "10.0.70.1";
      DNS = "10.0.70.1";
      DHCP = "no";
    };
  };

  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 4;
      memory = 6144; # MiB, ballooning ceiling
      balloon = 1024; # MiB, ballooning floor (Forgejo + Postgres working set)
      diskSize = "128G";
      # macAddress left as zeros; Proxmox assigns one on restore.
    };

    security = {
      privesc = "doas";
      apparmor.enable = true;
      polkit.enable = true;
      firewall.enable = true;
      fail2ban.enable = true;
    };

    zram.enable = true;

    services.forgejo.enable = true;
  };

  # Runner registration creds (UUID + TOKEN env lines), sops-encrypted to this
  # host's age key. Consumed as the runner's EnvironmentFile below.
  sops.secrets.action_runner.sopsFile = ../../system/secrets/hephaestus.yaml;

  # Forgejo Actions runner, colocated with the server. Host backend (no container
  # runtime) — jobs run directly as the gitea-runner DynamicUser, tools come from
  # hostPackages. Acceptable while only first-party code runs here; the moment
  # less-trusted/external code lands, lift this onto its own VLAN'd VM and repoint
  # the `nix` label at a podman/docker backend (workflows say `runs-on: nix`, so
  # they don't change). See the runner discussion in NOTES if revisiting.
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.hephaestus = {
      enable = true;
      name = "hephaestus";
      # Colocated: dial Forgejo on loopback, no hairpin through portunus. On a
      # move to a separate host this becomes the reachable Forgejo address (and a
      # re-registration with a fresh token happens anyway).
      url = "http://localhost:8080";
      # EnvironmentFile with the runner's registration TOKEN (a UUID line rides
      # along but the register flow ignores it — only TOKEN is read). sops decrypts
      # it to /run, root-readable; systemd sources it before dropping to the
      # gitea-runner user. The durable `.runner` identity lands in the mnemosyne-
      # persisted state dir below, so the token is consumed only on first register /
      # label change — it must still be valid (unexpired) at that first start.
      tokenFile = config.sops.secrets.action_runner.path;
      # Stable abstract label -> host backend. Workflows target `runs-on: nix`; the
      # backend behind the label can change later without editing any workflow.
      labels = ["nix:host"];
      # Host-backend jobs see only these on PATH. Module defaults + nix (the point),
      # cacert (node/TLS to github for actions), openssh (git remotes over ssh).
      hostPackages = with pkgs; [
        bash
        coreutils
        curl
        gawk
        git
        gnused
        nodejs
        wget
        nix
        openssh
        cacert
      ];
    };
  };

  # Runner registration (.runner) + label/token hashes. Persist across the tmpfs
  # root or it re-registers every boot and burns a fresh token each time.
  # The runner is a DynamicUser, so systemd keeps real StateDirectory= contents in
  # /var/lib/private/gitea-runner and leaves /var/lib/gitea-runner as a symlink to
  # it — persist the private path (the symlink would save nothing, and bind-mounting
  # the public path makes systemd fail StateDirectory setup with EBUSY trying to
  # migrate a mountpoint into /var/lib/private).
  mnemosyne.dirs = ["/var/lib/private/gitea-runner"];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
    python3
  ];
}
