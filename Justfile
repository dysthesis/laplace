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

image DISK PROFILE="chaos":
  #!/usr/bin/env sh
  set -euo pipefail
  if [ "{{PROFILE}}" = "chaos" ]; then
    nix build ".#nixosConfigurations.{{PROFILE}}.config.system.build.isoImage"
    sudo wipefs -a {{DISK}}
    ISO_PATH="$(find result/iso -maxdepth 1 -name '*.iso' -print -quit)"
    if [ -z "$ISO_PATH" ]; then
      echo "Failed to locate ISO artifact under result/iso" >&2
      exit 1
    fi
    sudo dd if="$ISO_PATH" of={{DISK}} status=progress conv=fsync
  else
    echo "Unsupported image profile: {{PROFILE}} (expected chaos)" >&2
    exit 1
  fi

clean:
  fd "core|result|out|test" --no-ignore-vcs -x rm

proxmox HOST:
  nix build .#nixosConfigurations.{{HOST}}.config.system.build.proxmoxVMA

# Push-deploy the Proxmox guests. `just deploy` does all of them; pass extra
# colmena args through, e.g. `just deploy --on bifrost`. Deploy reach-critical
# guests (bifrost/portunus/horos/hermes) one at a time.
deploy *ARGS:
  colmena apply --on @proxmox {{ARGS}}

deploy-one HOST *ARGS:
  colmena apply --on {{HOST}} {{ARGS}}

# Show which guests differ from their running system, without pushing anything.
# Sharper than `colmena apply dry-activate` (which copies the closure first):
# this only builds locally and reads the remote /run/current-system symlink.
deploy-diff:
  #!/usr/bin/env sh
  set -eu
  for pair in mneme=10.0.20.81 hermes=10.0.20.82 mimir=10.0.20.83 \
              garmr=10.0.20.84 horos=10.0.20.85 charon=10.0.20.10 \
              portunus=10.0.40.2 bifrost=10.0.40.3; do
    h=${pair%%=*}; ip=${pair#*=}
    out=$(nix build --no-link --print-out-paths \
      ".#nixosConfigurations.$h.config.system.build.toplevel")
    cur=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$ip" \
      readlink -f /run/current-system) || { printf '%-10s UNREACHABLE\n' "$h"; continue; }
    if [ "$out" = "$cur" ]; then printf '%-10s up-to-date\n' "$h"; \
    else printf '%-10s CHANGED\n' "$h"; fi
  done
