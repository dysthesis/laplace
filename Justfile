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
  #!/usr/bin/env sh
  set -eu
  for link in result result-*; do
    if [ -L "$link" ]; then
      rm -- "$link"
    fi
  done

proxmox HOST:
  nix build .#nixosConfigurations.{{HOST}}.config.system.build.proxmoxVMA

deploy *ARGS:
  colmena apply --on @server {{ARGS}}

deploy-one HOST *ARGS:
  #!/usr/bin/env sh
  set -eu
  trap 'rm -f ".gcroots/node-{{HOST}}"; rmdir .gcroots 2>/dev/null || true' EXIT
  target=$(nix eval --raw '.#colmena.{{HOST}}.deployment.targetHost')
  target_user=$(nix eval --raw '.#colmena.{{HOST}}.deployment.targetUser')
  colmena apply build --impure --on {{HOST}} --keep-result
  system=$(readlink -f '.gcroots/node-{{HOST}}')
  # Determinate Nix 3.22 aborts Colmena on unsigned imports.
  # Use this bypass only over authenticated root SSH.
  nix copy --no-check-sigs --to "ssh-ng://$target_user@$target" "$system"
  colmena apply --impure --on {{HOST}} {{ARGS}}

age-key TARGET:
  #!/usr/bin/env sh
  set -eu
  ssh {{TARGET}} '
    set -eu
    f=/nix/persist/etc/secrets/age/keys.txt
    install -d -m 700 "${f%/*}"
    if [ ! -s "$f" ]; then
      umask 077
      nix --extra-experimental-features "nix-command flakes" shell nixpkgs#age -c age-keygen -o "$f" >&2
    fi
    nix --extra-experimental-features "nix-command flakes" shell nixpkgs#age -c age-keygen -y "$f"
  '

tailnet-reconcile TARGET="":
  #!/usr/bin/env sh
  set -eu
  target={{quote(TARGET)}}
  if [ -z "$target" ]; then
    host=$(nix eval --raw '.#laplace.activeServices.headscale.host')
    address=$(nix eval --raw ".#laplace.hosts.$host.deployment.targetHost")
    target="root@$address"
  fi
  ssot=$(nix eval --json '.#laplace.nodes')
  live=$(ssh "$target" 'headscale nodes list --output json')
  problems=$(printf '%s' "$live" | nix shell nixpkgs#jq -c jq -c \
    --argjson ssot "$ssot" -f system/tailnet/reconcile.jq)
  if [ "$problems" != '[]' ]; then
    printf 'tailnet reconcile FAILED (live Headscale state != SSOT):\n%s\n' "$problems" >&2
    exit 1
  fi
  echo "tailnet reconcile OK: live tagged nodes, addresses, and tags == SSOT"
