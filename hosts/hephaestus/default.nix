# Forgejo host, running as a Proxmox guest. Everything generic to a Proxmox VM
# (disk layout, impermanence, bootloader, virtio, serial, qemuGuest, the archon
# admin user, the VMA image artifact) lives in the `proxmox` profile; this module
# only declares what is specific to this guest.
{pkgs, ...}: {
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 2;
      memory = 4096; # MiB, ballooning ceiling
      balloon = 1024; # MiB, ballooning floor (Forgejo + Postgres working set)
      diskSize = "64G";
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
