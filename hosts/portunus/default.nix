{pkgs, ...}: let
  fqdn = "dysthesis.com";
in {
  networking = {
    useNetworkd = true;
    useDHCP = false;
    nameservers = ["10.0.40.1"];
  };

  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      Address = "10.0.40.2/24";
      Gateway = "10.0.40.1";
      DNS = "10.0.40.1";
      DHCP = "no";
    };
  };

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
  };

  mnemosyne.dirs = ["/etc/config"];

  environment.systemPackages = with pkgs; [
    vim # for emergencies
    git # for pulling Nix flakes
  ];
}
