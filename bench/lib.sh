# shellcheck shell=bash

log() { printf '\033[1;34m::\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() {
    printf '\033[1;31mxx\033[0m %s\n' "$*" >&2
    exit 1
}

need() { command -v "$1" >/dev/null 2>&1 || die "missing tool: $1 (provision via bench/default.nix)"; }

resolve_store() {
    local flake="$1" inst="$2"
    nix build --no-link --print-out-paths "${flake}#${inst}" ||
        die "could not build ${flake}#${inst}"
}

fish_xdg_data_dirs() {
    local wrapped="$1"
    "${wrapped}/bin/fish" --no-config -c "printf '%s\n' \"\$XDG_DATA_DIRS\"" 2>/dev/null ||
        "${wrapped}/bin/fish" -c "printf '%s\n' \"\$XDG_DATA_DIRS\""
}

find_fish_user_config() {
    local dirs="$1" d
    for d in ${dirs//:/ }; do
        if [[ -f "$d/fish/vendor_conf.d/user_config.fish" ]]; then
            printf '%s\n' "$d/fish/vendor_conf.d/user_config.fish"
            return 0
        fi
    done
    return 1
}

capture_provenance() {
    local out="$1"
    shift
    local governor load gitrev gitstatus gitdirty
    governor="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
    load="$(cut -d' ' -f1-3 </proc/loadavg 2>/dev/null || echo unknown)"
    gitrev="$(git rev-parse HEAD 2>/dev/null || echo none)"
    gitstatus="$(git status --porcelain 2>/dev/null || true)"
    gitdirty="$([[ -n $gitstatus ]] && echo true || echo false)"

    local extra='{}'
    if [[ $# -gt 0 ]]; then
        local args=() kv
        for kv in "$@"; do args+=(--arg "${kv%%=*}" "${kv#*=}"); done
        extra="$(jq -n "${args[@]}" '$ARGS.named')"
    fi

    jq -n \
        --arg ts "$(date -Iseconds)" \
        --arg host "$(hostname 2>/dev/null || echo unknown)" \
        --arg kernel "$(uname -srmo 2>/dev/null || echo unknown)" \
        --arg nproc "$(nproc 2>/dev/null || echo unknown)" \
        --arg governor "$governor" \
        --arg load "$load" \
        --arg gitrev "$gitrev" \
        --arg gitdirty "$gitdirty" \
        --arg nix "$(nix --version 2>/dev/null || echo unknown)" \
        --arg hyperfine "$(hyperfine --version 2>/dev/null || echo absent)" \
        --arg strace "$(strace --version 2>&1 | head -1 || echo absent)" \
        --arg python "$(python3 --version 2>/dev/null || echo unknown)" \
        --argjson extra "$extra" \
        '{timestamp:$ts, host:$host, kernel:$kernel, nproc:$nproc,
      cpu_governor:$governor, loadavg:$load,
      git_rev:$gitrev, git_dirty:$gitdirty,
      tools:{nix:$nix, hyperfine:$hyperfine, strace:$strace, python:$python},
      targets:$extra}' >"$out"
}

# Disable matching init lines. Return the share path.
gen_ablation_config() {
    local outdir="$1" cfg="$2" regex="$3"
    local vd="$outdir/share/fish/vendor_conf.d"
    mkdir -p "$vd"
    # Use \x01 as the delimiter because the patterns contain |.
    local d=$'\x01'
    sed -E "s${d}^(.*(${regex}).*)\$${d}# ABLATED: \\1${d}" "$cfg" >"$vd/user_config.fish"
    printf '%s\n' "$outdir/share"
}

pin() {
    if [[ -n ${BENCH_CORE:-} ]] && command -v taskset >/dev/null 2>&1; then
        taskset -c "$BENCH_CORE" "$@"
    else
        "$@"
    fi
}
