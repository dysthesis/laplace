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

# Generate (idempotent) a persisted sops age key on a host and print its public
# recipient for .sops.yaml. TARGET is an ssh destination, e.g. root@10.0.20.81.
# The path matches sops.age.keyFile in system/secrets - under /nix/persist so it
# survives impermanence (/etc/secrets would not). Add the printed age1... line to
# .sops.yaml, then `sops` the secret so this host can decrypt it.
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

# Runtime half of PLAN §5 layer 4 (gotcha 4): assert the LIVE Headscale tags
# match the SSOT (system/tailnet). The nft layer pins by IP (Nix-authoritative)
# while Headscale enforces by the tag assigned at enrolment (runtime) - if a node
# enrolled under the wrong tag the two layers silently diverge. NOT a flake check:
# the build sandbox has no network. Run manually or on a timer. Guests (untagged,
# absent from the SSOT) are intentionally ignored. Exits non-zero on any drift.
tailnet-reconcile TARGET="root@10.0.50.2":
  #!/usr/bin/env sh
  set -eu
  ssot=$(nix eval --json '.#nixosConfigurations.bifrost.config.laplace.tailnet.nodes')
  live=$(ssh {{TARGET}} 'headscale nodes list --output json')
  problems=$(printf '%s' "$live" | nix shell nixpkgs#jq -c jq -r --argjson ssot "$ssot" '
    ($ssot | to_entries | map({key: .key, want: (.value.tags | sort)})) as $want
    | (map({key: (.givenName // .name), value: ((.tags // []) | map(sub("^tag:"; "")) | sort)}) | from_entries) as $have
    | [ $want[] | .key as $h | ($have[$h]) as $got
        | if $got == null then "MISSING from tailnet: \($h)"
          elif $got != .want then "DRIFT \($h): live=\($got|join(",")) ssot=\(.want|join(","))"
          else empty end ]
    | .[]')
  if [ -n "$problems" ]; then
    printf 'tailnet tag reconcile FAILED (live Headscale tags != SSOT):\n%s\n' "$problems" >&2
    exit 1
  fi
  echo "tailnet tag reconcile OK: live tags == SSOT for all nodes"
