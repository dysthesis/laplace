# Let Proxmox handle disk size
{
  boot.growPartition = true;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };
}
