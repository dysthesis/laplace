vcs := `if command -v jj >/dev/null 2>&1 \
           && jj root --ignore-working-copy --quiet >/dev/null 2>&1; then \
            printf 'jj'; \
          else \
            printf 'git'; \
          fi`

update FLAKE="":
  #!/usr/bin/env sh
  nix flake update --commit-lock-file {{FLAKE}}
  if [ "{{vcs}}" = "jj" ]; then
    jj git push
  else
    git push
  fi

rebuild:
  nh os switch

pull:
  #!/usr/bin/env sh
  if [ "{{vcs}}" = "jj" ]; then
    jj git fetch
  else
    git pull
  fi

sync: pull rebuild

upgrade FLAKE="": pull (update FLAKE) rebuild

format HOST:
  #!/usr/bin/env sh
  sudo disko \
    --mode destroy,format,mount \
    --yes-wipe-all-disks \
    ./hosts/{{HOST}}/disks.nix

install HOST: (format HOST)
  #!/usr/bin/env sh
  sudo nixos-install \
    --impure \
    --flake .#{{HOST}} \
    --root /mnt \
    --show-trace \
    --no-root-password

remote HOST ADDR:
  nix run ."#install-{{HOST}}" -- --target-host root@{{ADDR}}

image DISK PROFILE="chaos":
  #!/usr/bin/env sh
  set -euo pipefail
  if [ "{{PROFILE}}" = "erebus" ]; then
    nix build ".#nixosConfigurations.{{PROFILE}}.config.system.build.sdImage"
    sudo wipefs -a {{DISK}}
    zstdcat result/sd-image/nixos-image-sd-card-*-linux.img.zst | sudo dd of={{DISK}} status=progress
  elif [ "{{PROFILE}}" = "chaos" ]; then
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

clean:
  fd "core|result|out|test" --no-ignore-vcs -x rm
