format HOST:
  sudo nix run 'github:nix-community/disko/latest' -- \
    --mode destroy,format,mount \
    ./hosts/{{HOST}}/disks.nix

install HOST: (format HOST)
  sudo nixos-install \
    --impure \
    --flake .#{{HOST}} \
    --root /mnt \
    --show-trace \
    --no-root-password
