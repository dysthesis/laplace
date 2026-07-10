# Forgejo host, running as a Proxmox guest. Everything generic to a Proxmox VM
# (disk layout, impermanence, bootloader, virtio, serial, qemuGuest, the archon
# admin user, the VMA image artifact) lives in the `proxmox` profile; this module
# only declares what is specific to this guest.
#
# hephaestus lives on its own VLAN70 (10.0.70.2). Forgejo serves plain HTTP on
# :8080; TLS terminates at the edge on portunus (10.0.40.2, DMZ), which gates
# git.dysthesis.com behind Anubis and reverse-proxies it across a single
# VLAN40->VLAN70 pinhole — the same split bifrost/headscale use. The Actions
# runner lives on talos (10.0.80.2, VLAN80) and dials :8080 directly. So :8080
# is opened ONLY to those two.
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
    # portunus (10.0.40.2) proxies to Forgejo's HTTP port; talos (10.0.80.2) is
    # the Actions runner hitting the API + cloning over it. OPNsense must also
    # pass VLAN40 (10.0.40.2) and VLAN80 (10.0.80.2) -> 10.0.70.2:<HTTP_PORT>.
    firewall.extraInputRules = ''
      ip saddr { 10.0.40.2, 10.0.80.2 } tcp dport ${toString config.services.forgejo.settings.server.HTTP_PORT} accept
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
    harden = ["malloc" "kernel"];
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

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
    python3
  ];
}
