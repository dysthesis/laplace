vcs := `if command -v jj >/dev/null 2>&1 \
           && jj root --ignore-working-copy --quiet >/dev/null 2>&1; then \
             printf 'jj'; \
           else \
             printf 'git'; \
           fi`
retirement_home_service := "minecraft-server-retirement-home"
retirement_home_stdin := "/run/minecraft/retirement-home.stdin"

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

# Deploy Proxmox guests; handle reach-critical hosts one at a time.
deploy *ARGS:
  colmena apply --on @proxmox {{ARGS}}

deploy-one HOST *ARGS:
  colmena apply --on {{HOST}} {{ARGS}}

# Create a persisted SOPS age key and print its recipient.
# Add the recipient to .sops.yaml before encrypting host secrets.
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

# Send a server command through the protected stdin FIFO.
mc +CMD:
  printf '%s\n' "{{CMD}}" | doas tee {{retirement_home_stdin}} >/dev/null

# Start Chunky pregen at 0,0; WORLD selects the dimension.
# Read progress with pregen-status or pregen-watch.
pregen-start RADIUS="5000" WORLD="minecraft:overworld": (mc ("chunky world " + WORLD)) (mc "chunky center 0 0") (mc ("chunky radius " + RADIUS)) (mc "chunky start")

pregen-pause: (mc "chunky pause")

pregen-resume: (mc "chunky continue")

# Cancel deletes the task's progress; Chunky wants a confirm within 10s.
pregen-cancel: (mc "chunky cancel") (mc "chunky confirm")

pregen-status: (mc "chunky progress")
  #!/usr/bin/env sh
  sleep 1
  journalctl -u {{retirement_home_service}} -n 15 --no-pager | grep -i chunky || echo "no chunky output in recent log"

pregen-watch:
  journalctl -fu {{retirement_home_service}}

tailnet-reconcile TARGET="root@10.0.50.2":
  #!/usr/bin/env sh
  set -eu
  ssot=$(nix eval --json '.#nixosConfigurations.bifrost.config.laplace.tailnet.nodes')
  live=$(ssh {{TARGET}} 'headscale nodes list --output json')
  problems=$(printf '%s' "$live" | nix shell nixpkgs#jq -c jq -r \
    --argjson ssot "$ssot" -f system/tailnet/reconcile.jq)
  if [ -n "$problems" ]; then
    printf 'tailnet reconcile FAILED (live Headscale state != SSOT):\n%s\n' "$problems" >&2
    exit 1
  fi
  echo "tailnet reconcile OK: live tagged nodes, addresses, and tags == SSOT"
