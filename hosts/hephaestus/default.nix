# Forgejo host, running as a Proxmox guest. Everything generic to a Proxmox VM
# (disk layout, impermanence, bootloader, virtio, serial, qemuGuest, the archon
# admin user, the VMA image artifact) lives in the `proxmox` profile; this module
# only declares what is specific to this guest.
{
  config,
  pkgs,
  ...
}: {
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 2;
      memory = 4096; # MiB
      diskSize = "32G";
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

    nh = {
      enable = true;
      flakePath = "/etc/config";
    };

    services.forgejo.enable = true;
  };

  # Persist the on-disk flake clone used for remote rebuilds. Forgejo + postgres
  # state dirs are contributed by the forgejo module; base dirs (/etc/ssh, ...)
  # by mnemosyne itself - so no mkForce, just this host-specific addition.
  mnemosyne.dirs = ["/etc/config"];

  sops.secrets."cloudflared/hephaestus" = {};

  services.cloudflared = {
    enable = true;
    tunnels."4627a163-b910-476e-953f-353d3bfaa6d1" = {
      credentialsFile = config.sops.secrets."cloudflared/hephaestus".path;
      default = "http_status:404";
    };
  };

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
    python3
  ];
}
