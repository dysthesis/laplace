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
  # host's age key. Consumed as the runner's EnvironmentFile (tokenFile). Secret
  # wiring is inherently per-host (sops-nix per-host age key); the runner logic
  # itself lives in system/services/forgejo-runner.
  sops.secrets.action_runner.sopsFile = ../../system/secrets/hephaestus.yaml;

  # Forgejo Actions runner, colocated with the server (host backend, label
  # `nix:host`). Host-backend jobs run directly as the gitea-runner DynamicUser
  # with `nix` on PATH — acceptable while only first-party code runs here. When
  # less-trusted/external code lands, move this onto its own VLAN'd VM and repoint
  # `url` at the reachable Forgejo address (a fresh token forces re-registration
  # anyway); workflows say `runs-on: nix`, so they don't change. Persistence,
  # hostPackages, unit hardening and the label assertion all live in the module.
  laplace.services.forgejo-runner = {
    enable = true;
    # Colocated: dial Forgejo on loopback, no hairpin through portunus.
    url = "http://localhost:8080";
    tokenFile = config.sops.secrets.action_runner.path;
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
    python3
  ];
}
