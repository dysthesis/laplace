update FLAKE="":
  nix flake update --commit-lock-file {{FLAKE}} && git push

rebuild:
  nh os switch

pull:
  git pull

sync: pull rebuild

upgrade FLAKE="": sync (update FLAKE) rebuild

format HOST:
  sudo disko \
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

image DISK:
  nix build ".#nixosConfigurations.erebus.config.system.build.sdImage" && \
  sudo wipefs -a {{DISK}} && \
  zstdcat result/sd-image/nixos-image-sd-card-*-linux.img.zst  | sudo dd of={{DISK}} status=progress

sync-server:
  rsync -av -e ssh $(pwd) demiurge@192.168.1.185:Documents/Projects/laplace

clean:
  fd "core|result|out|test" --no-ignore-vcs -x rm
