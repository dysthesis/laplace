format HOST PASSWORD:
  echo "{{PASSWORD}}" > /tmp/luks.key
  sudo nix run 'github:nix-community/disko/latest' -- \
    --mode destroy,format,mount \
    --yes-wipe-all-disks \
    ./hosts/{{HOST}}/disks.nix

install HOST PASSWORD: (format HOST PASSWORD)
  sudo nixos-install \
    --impure \
    --flake .#{{HOST}} \
    --root /mnt \
    --show-trace \
    --no-root-password
