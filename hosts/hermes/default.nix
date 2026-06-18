{pkgs, ...}: {
  laplace = {
    profiles = ["proxmox"];
    proxmox = {
      cores = 1;
      memory = 2048; # MiB
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

    nh = {
      enable = true;
      flakePath = "/etc/config";
    };

    services = {
      adguardhome.enable = true;
      tailscale.enable = true;
    };
  };

  # Persist the on-disk flake clone used for remote rebuilds. The AdGuard state
  # dir is contributed by the adguardhome module; base dirs (/etc/ssh, ...) by
  # mnemosyne itself - so no mkForce, just this host-specific addition.
  mnemosyne.dirs = ["/etc/config"];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
