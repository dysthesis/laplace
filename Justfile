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

# Push-deploy the Proxmox guests. `just deploy` does all of them; pass extra
# colmena args through, e.g. `just deploy --on bifrost`. Deploy reach-critical
# guests (bifrost/portunus/horos/hermes) one at a time.
deploy *ARGS:
  colmena apply --on @proxmox {{ARGS}}

deploy-one HOST *ARGS:
  colmena apply --on {{HOST}} {{ARGS}}

retirement-home-prepare:
  sudo systemd-tmpfiles --create --prefix=/srv/minecraft
  sudo install -d -m 0770 -o minecraft -g minecraft /srv/minecraft/retirement-home

retirement-home-start: retirement-home-prepare
  sudo systemctl start {{retirement_home_service}}

retirement-home-stop:
  sudo systemctl stop {{retirement_home_service}}

retirement-home-logs:
  sudo journalctl -fu {{retirement_home_service}}

retirement-home-cmd CMD:
  sudo sh -c 'printf "%s\n" "$1" > {{retirement_home_stdin}}' sh "{{CMD}}"

retirement-home-pregen RADIUS="10000" WORLD="world_nether" SHAPE="circle": retirement-home-prepare
  #!/usr/bin/env bash
  set -euo pipefail

  service="{{retirement_home_service}}"
  stdin="{{retirement_home_stdin}}"

  if sudo systemctl is-active --quiet "$service"; then
    printf 'retirement-home already active; assuming console is ready.\n'
  else
    started="$(date --iso-8601=seconds)"
    sudo systemctl start "$service"
    printf 'Waiting for retirement-home to finish startup...\n'

    until sudo journalctl -u "$service" --since "$started" --no-pager | grep -q 'Done ('; do
      if ! sudo systemctl is-active --quiet "$service"; then
        sudo journalctl -u "$service" -n 80 --no-pager >&2
        exit 1
      fi
      sleep 10
    done
  fi

  sudo sh -c 'out=$1; shift; printf "%s\n" "$@" > "$out"' sh "$stdin" \
    "chunky world {{WORLD}}" \
    "chunky shape {{SHAPE}}" \
    "chunky spawn" \
    "chunky radius {{RADIUS}}" \
    "chunky start"

  printf 'Chunky pregen started: world=%s shape=%s radius=%s.\n' "{{WORLD}}" "{{SHAPE}}" "{{RADIUS}}"
  printf 'Watch logs: just retirement-home-logs\n'

retirement-home-progress:
  just retirement-home-cmd 'chunky progress'
