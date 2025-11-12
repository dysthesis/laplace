update FLAKE="":
  nix flake update --commit-lock-file {{FLAKE}} && git push

rebuild:
  nh os switch

pull:
  git pull

sync: pull rebuild

upgrade FLAKE="": pull (update FLAKE) rebuild

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

remote HOST ADDR:
  nix run ."#install-{{HOST}}" -- --target-host root@{{ADDR}}

image DISK PROFILE="installer":
  #!/usr/bin/env sh
  set -euo pipefail
  if [ "{{PROFILE}}" = "erebus" ]; then
    nix build ".#nixosConfigurations.{{PROFILE}}.config.system.build.sdImage"
    sudo wipefs -a {{DISK}}
    zstdcat result/sd-image/nixos-image-sd-card-*-linux.img.zst | sudo dd of={{DISK}} status=progress
  elif [ "{{PROFILE}}" = "installer" ]; then
    nix build ".#nixosConfigurations.{{PROFILE}}.config.system.build.isoImage"
    sudo wipefs -a {{DISK}}
    ISO_PATH="$(find result/iso -maxdepth 1 -name '*.iso' -print -quit)"
    if [ -z "$ISO_PATH" ]; then
      echo "Failed to locate ISO artifact under result/iso" >&2
      exit 1
    fi
    sudo dd if="$ISO_PATH" of={{DISK}} status=progress conv=fsync
  else
    echo "Unsupported image profile: {{PROFILE}} (expected erebus or installer)" >&2
    exit 1
  fi

sync-server:
  rsync -av -e ssh $(pwd) demiurge@192.168.1.185:Documents/Projects/laplace

clean:
  fd "core|result|out|test" --no-ignore-vcs -x rm
