format HOST:
  sudo disko
    --mode destroy,format,mount \
    --yes-wipe-all-disks \
    ./hosts/{{HOST}}/disks.nix

install HOST: (format HOST)
  sudo nixos-install \
    --impure \
    --flake .#{{HOST}} \
    --root /mnt \
    --show-trace \
    --no-root-password
