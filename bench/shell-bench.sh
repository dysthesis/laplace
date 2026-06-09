#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# shell-bench.sh - standardised, reproducible shell-startup benchmark for this
# flake. Benchmarks the EXACT Nix-built artifacts (not whatever is on $PATH),
# captures provenance, and reports the metrics that actually correlate with
# perceived latency (after zsh-bench), not the misleading `time shell -i -c
# exit` floor.
#
# Tiers:  T0 provenance | T1 coarse floor (hyperfine) | T2 perceptual metrics
#         (PTY harness) | T3 attribution (fish --profile-startup + ablation) |
#         T4 syscall/exec accounting (strace) | T5 A/B compare.
#
# Run `bench/shell-bench.sh --help`. Designed to be driven via `nix run .#bench`.
# ---------------------------------------------------------------------------
set -euo pipefail

HERE="${BENCH_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=lib.sh
source "$HERE/lib.sh"
PROBE="$HERE/pty-probe.py"
STATS="$HERE/stats.py"
UI="$HERE/ui.py"
ui() { python3 "$UI" "$@" || true; }   # rich status banners (stderr), best-effort

# ---- defaults --------------------------------------------------------------
FLAKE="."
HOST="$(hostname 2>/dev/null || echo unknown)"
TARGETS="fish,bash,devshell"
MODES="isolated"
SPAWNS="interactive"
RUNS=10                 # cold spawns for first_prompt/first_command/exit
ITERS=30                # inner iterations for command_lag/input_lag
WARMUP=3
COLS=120
ROWS=30
OUTDIR=""
TIERS="all"
DO_ABLATION=1
AB=()                   # --ab SHELL_A SHELL_B
DRYRUN=0
export BENCH_CORE="${BENCH_CORE:-}"
FISH_PROMPT_REGEX='(◎|○)'   # starship [character] success/error symbols

usage() {
  cat >&2 <<EOF
shell-bench.sh - benchmark this flake's shells (Nix artifacts, pinned).

  --flake REF        flake to benchmark (default: .)
  --host NAME        nixos host whose pkgs.configured.* to build (default: $(hostname))
  --targets LIST     comma: fish,bash,devshell (default: all)
  --modes LIST       comma: isolated,in-situ (default: isolated)
  --spawns LIST      comma: interactive,login (default: interactive)
  --runs N           cold spawns per spawn-metric (default: $RUNS)
  --iters N          inner iterations for lag metrics (default: $ITERS)
  --warmup N         hyperfine warmup runs (default: $WARMUP)
  --cols N --rows N  PTY size (prompt width matters) (default: ${COLS}x${ROWS})
  --core N           pin benchmarked process to CPU core N (taskset)
  --tiers LIST       comma: coarse,metrics,attrib,syscall  (default: all)
  --no-ablation      skip the fish config-line ablation sweep
  --ab A B           A/B two shell binaries (interleaved) and compare
  --out DIR          output directory (default: bench/results/<timestamp>)
  --dry-run          print what would run, build nothing
  -h, --help

Examples:
  bench/shell-bench.sh --modes isolated,in-situ
  bench/shell-bench.sh --targets fish --tiers metrics,attrib
  bench/shell-bench.sh --ab /nix/store/...-fish-A/bin/fish /nix/store/...-fish-B/bin/fish
EOF
  exit "${1:-0}"
}

# ---- arg parsing -----------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --flake)   FLAKE="$2"; shift 2;;
    --host)    HOST="$2"; shift 2;;
    --targets) TARGETS="$2"; shift 2;;
    --modes)   MODES="$2"; shift 2;;
    --spawns)  SPAWNS="$2"; shift 2;;
    --runs)    RUNS="$2"; shift 2;;
    --iters)   ITERS="$2"; shift 2;;
    --warmup)  WARMUP="$2"; shift 2;;
    --cols)    COLS="$2"; shift 2;;
    --rows)    ROWS="$2"; shift 2;;
    --core)    BENCH_CORE="$2"; shift 2;;
    --tiers)   TIERS="$2"; shift 2;;
    --no-ablation) DO_ABLATION=0; shift;;
    --ab)      AB=("$2" "$3"); shift 3;;
    --out)     OUTDIR="$2"; shift 2;;
    --dry-run) DRYRUN=1; shift;;
    -h|--help) usage 0;;
    *) die "unknown arg: $1 (see --help)";;
  esac
done

: "${OUTDIR:=bench/results/$(date +%Y%m%dT%H%M%S)}"
mkdir -p "$OUTDIR"

ui rule "laplace shell-bench"
ui kv "run plan" \
  "flake=$FLAKE" "host=$HOST" "targets=$TARGETS" "modes=$MODES" \
  "spawns=$SPAWNS" "tiers=$TIERS" "runs=$RUNS" "iters=$ITERS" \
  "core=${BENCH_CORE:-none}" "out=$OUTDIR"

want_tier() { [[ "$TIERS" == all ]] || [[ ",$TIERS," == *",$1,"* ]]; }
has_target() { [[ ",$TARGETS," == *",$1,"* ]]; }

for t in nix jq python3; do need "$t"; done
want_tier coarse   && need hyperfine
want_tier syscall  && need strace

# Merge N pty-probe JSON files into one (concatenating each metric's samples).
merge_pty() {
  local out="$1"; shift
  jq -s '{label:.[0].label, mode:.[0].mode, spawn_mode:.[0].spawn_mode,
          shell:.[0].shell, winsize:.[0].winsize, params:.[0].params,
          samples: (reduce .[] as $x ({};
            reduce ($x.samples|keys[]) as $k (.;
              .[$k] = ((.[$k] // []) + $x.samples[$k]))))}' "$@" > "$out"
}

# ---- environment regimes ---------------------------------------------------
# Echoes `env` assignments for the chosen mode. Isolated = clean HOME + a fresh
# tmpfs XDG_RUNTIME_DIR (so fish's tmpfs-redirected config starts empty and
# reproducible) while keeping the real PATH (the shell still needs to exec
# starship/zoxide/task/git). In-situ = the real session, untouched.
mk_runenv() {
  local mode="$1"
  case "$mode" in
    isolated)
      local h r
      h="$(mktemp -d "${TMPDIR:-/tmp}/bench-home.XXXXXX")"
      r="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/bench-run.XXXXXX")"
      printf '%s\n' \
        "HOME=$h" "XDG_RUNTIME_DIR=$r" \
        "XDG_CONFIG_HOME=$h/.config" "XDG_DATA_HOME=$h/.local/share" \
        "XDG_CACHE_HOME=$h/.cache" "XDG_STATE_HOME=$h/.local/state" \
        "TERM=xterm-256color" "LC_ALL=C.UTF-8" "BENCH_TMP=$h"
      ;;
    in-situ)
      printf '%s\n' "TERM=${TERM:-xterm-256color}" "LC_ALL=${LC_ALL:-C.UTF-8}"
      ;;
    *) die "unknown mode: $mode";;
  esac
}

# ---- tiers -----------------------------------------------------------------
# T1: coarse floor. Labelled clearly so nobody mistakes it for the headline.
tier_coarse() {
  local label="$1" shellbin="$2" login="$3"; shift 3
  local -a runenv=("$@")
  local args=("-i" "-c" "exit"); [[ "$login" == 1 ]] && args=("-l" "${args[@]}")
  local out="$OUTDIR/${label}.coarse.json"
  log "T1 coarse: $label  ($shellbin ${args[*]})"
  [[ $DRYRUN == 1 ]] && return 0
  pin env "${runenv[@]}" hyperfine --warmup "$WARMUP" --runs "$RUNS" \
    --export-json "$out" --shell=none -- \
    "$shellbin ${args[*]}" >/dev/null 2>&1 \
    || warn "coarse failed for $label"
}

# T2: perceptual metrics via the PTY harness.
tier_metrics() {
  local label="$1" shellbin="$2" login="$3" regex="$4"; shift 4
  local -a runenv=("$@")
  local out="$OUTDIR/${label}.metrics.json"
  local -a probeargs=(--shell "$shellbin" --cols "$COLS" --rows "$ROWS"
    --prompt-runs "$RUNS" --inner-iters "$ITERS"
    --label "$label" --mode "${BENCH_MODE:-}" --spawn-mode "$([[ $login == 1 ]] && echo login || echo interactive)")
  [[ "$login" == 1 ]] && probeargs+=(--login)
  [[ -n "$regex" ]] && probeargs+=(--prompt-regex "$regex")
  log "T2 metrics: $label"
  [[ $DRYRUN == 1 ]] && return 0
  pin env "${runenv[@]}" python3 "$PROBE" "${probeargs[@]}" > "$out" \
    || { warn "metrics failed for $label"; return 0; }
  python3 "$STATS" summarize "$out" || true
}

# T3a: fish-native per-init-line attribution.
tier_profile_fish() {
  local label="$1" shellbin="$2"; shift 2
  local -a runenv=("$@")
  local prof="$OUTDIR/${label}.profile-startup.log"
  log "T3 profile: $label (fish --profile-startup)"
  [[ $DRYRUN == 1 ]] && return 0
  pin env "${runenv[@]}" "$shellbin" --profile-startup "$prof" -i -c exit \
    >/dev/null 2>&1 || warn "profile-startup failed for $label"
  # fish profile columns: Time(us)  Sum(us)  Command. Rank by self-time.
  if [[ -s "$prof" ]]; then
    { printf 'top init lines by self-time (us):\n'
      tail -n +2 "$prof" | sort -t$'\t' -k1 -rn | head -25
    } > "$OUTDIR/${label}.profile-top.txt"
    log "  -> $OUTDIR/${label}.profile-top.txt"
  fi
}

# T3b: ablation - rebuild the fish config minus each suspect line, measure the
# delta. Cross-validates the profiler: the profiler says X costs Y in isolation;
# ablation shows X's true cost including its second-order effects.
tier_ablation_fish() {
  local label="$1" wrapped="$2" unwrapped_bin="$3"; shift 3
  local -a runenv=("$@")
  [[ $DO_ABLATION == 1 ]] || return 0
  log "T3 ablation: $label"

  local dds cfg loadplugin
  dds="$(fish_xdg_data_dirs "$wrapped" | paste -sd: -)" || { warn "no XDG_DATA_DIRS"; return 0; }
  cfg="$(find_fish_user_config "$dds")" || { warn "user_config.fish not found"; return 0; }
  loadplugin="$(find "${dds//:/ }" -name load_plugin.fish 2>/dev/null | head -1 || true)"
  log "  config: $cfg"

  # Suspects worth ablating: name -> extended-regex matching the init line(s).
  local -a names=(dbus task_startup zoxide starship_init direnv transience plugins)
  local -a regexes=(
    'dbus-update-activation-environment'
    'next due\.before'
    'zoxide.*init'
    'starship.*init fish'
    'direnv hook fish'
    'enable_transience'
    'load_plugin '
  )

  # Baseline: reconstructed config, nothing ablated (regex matches nothing), run
  # via the SAME unwrapped binary, so deltas isolate exactly the removed line.
  local base_share base_json
  base_share="$(gen_ablation_config "$OUTDIR/abl/_baseline" "$cfg" "$loadplugin" '$^')"
  [[ $DRYRUN == 1 ]] && return 0
  base_json="$OUTDIR/abl/_baseline.json"
  pin env "${runenv[@]}" XDG_DATA_DIRS="$base_share" python3 "$PROBE" \
    --shell "$unwrapped_bin" --cols "$COLS" --rows "$ROWS" \
    --prompt-runs "$RUNS" --inner-iters "$ITERS" \
    --prompt-regex "$FISH_PROMPT_REGEX" --skip exit \
    --label "${label}-baseline" > "$base_json" 2>/dev/null || { warn "ablation baseline failed"; return 0; }

  local i
  for i in "${!names[@]}"; do
    local nm="${names[$i]}" rx="${regexes[$i]}"
    local share var_json
    share="$(gen_ablation_config "$OUTDIR/abl/$nm" "$cfg" "$loadplugin" "$rx")"
    var_json="$OUTDIR/abl/$nm.json"
    pin env "${runenv[@]}" XDG_DATA_DIRS="$share" python3 "$PROBE" \
      --shell "$unwrapped_bin" --cols "$COLS" --rows "$ROWS" \
      --prompt-runs "$RUNS" --inner-iters "$ITERS" \
      --prompt-regex "$FISH_PROMPT_REGEX" --skip exit \
      --label "minus-$nm" > "$var_json" 2>/dev/null || { warn "ablation $nm failed"; continue; }
    log "  delta from removing '$nm':"
    python3 "$STATS" compare "$base_json" "$var_json" || true
    python3 "$STATS" compare "$base_json" "$var_json" --json \
      > "$OUTDIR/abl/$nm.compare.json" || true
  done
}

# T4: syscall / exec accounting. Each `tool init`, `task`, dbus round-trip is a
# fork+exec; counting them explains where startup wall-time goes.
tier_syscall() {
  local label="$1" shellbin="$2" login="$3"; shift 3
  local -a runenv=("$@")
  local args=("-i" "-c" "exit"); [[ "$login" == 1 ]] && args=("-l" "${args[@]}")
  local out="$OUTDIR/${label}.strace.txt"
  log "T4 syscall: $label"
  [[ $DRYRUN == 1 ]] && return 0
  pin env "${runenv[@]}" strace -f -c -o "$out" \
    "$shellbin" "${args[@]}" >/dev/null 2>&1 || warn "strace -c failed for $label"
  pin env "${runenv[@]}" strace -f -e trace=execve -o "$OUTDIR/${label}.execve.txt" \
    "$shellbin" "${args[@]}" >/dev/null 2>&1 || true
  if [[ -s "$OUTDIR/${label}.execve.txt" ]]; then
    local n; n="$(grep -c 'execve(' "$OUTDIR/${label}.execve.txt" || echo 0)"
    log "  execve count (processes spawned at startup): $n"
  fi
}

# ---- A/B mode --------------------------------------------------------------
run_ab() {
  local a="$1" b="$2"
  ui rule "A/B compare (interleaved)"
  log "A/B: interleaving two shells, 2 rounds each"
  local -a runenv; mapfile -t runenv < <(mk_runenv isolated)
  local af=() bf=() round
  for round in 1 2; do
    pin env "${runenv[@]}" python3 "$PROBE" --shell "$a" --cols "$COLS" --rows "$ROWS" \
      --prompt-runs $((RUNS/2)) --inner-iters $((ITERS/2)) \
      --prompt-regex "$FISH_PROMPT_REGEX" --skip exit --label A \
      > "$OUTDIR/ab.A.$round.json"
    pin env "${runenv[@]}" python3 "$PROBE" --shell "$b" --cols "$COLS" --rows "$ROWS" \
      --prompt-runs $((RUNS/2)) --inner-iters $((ITERS/2)) \
      --prompt-regex "$FISH_PROMPT_REGEX" --skip exit --label B \
      > "$OUTDIR/ab.B.$round.json"
    af+=("$OUTDIR/ab.A.$round.json"); bf+=("$OUTDIR/ab.B.$round.json")
  done
  merge_pty "$OUTDIR/ab.A.json" "${af[@]}"
  merge_pty "$OUTDIR/ab.B.json" "${bf[@]}"
  python3 "$STATS" compare "$OUTDIR/ab.A.json" "$OUTDIR/ab.B.json" | tee "$OUTDIR/ab.report.txt"
  python3 "$STATS" compare "$OUTDIR/ab.A.json" "$OUTDIR/ab.B.json" --json > "$OUTDIR/ab.compare.json"
}

if [[ ${#AB[@]} -eq 2 ]]; then
  run_ab "${AB[0]}" "${AB[1]}"
  log "A/B done -> $OUTDIR"
  exit 0
fi

# ---- resolve artifacts -----------------------------------------------------
log "Resolving Nix artifacts for host '$HOST' from flake '$FLAKE' ..."
FISH_WRAP=""; FISH_UNWRAP=""; BASH_WRAP=""
if has_target fish || [[ $DO_ABLATION == 1 ]]; then
  if [[ $DRYRUN == 0 ]]; then
    FISH_WRAP="$(resolve_store "$FLAKE" "nixosConfigurations.$HOST.pkgs.configured.fish")"
    FISH_UNWRAP="$(resolve_store "$FLAKE" "nixosConfigurations.$HOST.pkgs.fish")"
  fi
  log "  fish (wrapped):   ${FISH_WRAP:-<dry>}"
fi
if has_target bash; then
  [[ $DRYRUN == 0 ]] && BASH_WRAP="$(resolve_store "$FLAKE" "nixosConfigurations.$HOST.pkgs.configured.bash")"
  log "  bash (wrapped):   ${BASH_WRAP:-<dry>}"
fi

capture_provenance "$OUTDIR/provenance.json" \
  "fish_wrapped=${FISH_WRAP}" "fish_unwrapped=${FISH_UNWRAP}" "bash_wrapped=${BASH_WRAP}" \
  "flake=${FLAKE}" "host=${HOST}"
log "Provenance -> $OUTDIR/provenance.json"

# ---- main sweep ------------------------------------------------------------
IFS=',' read -ra MODE_LIST  <<< "$MODES"
IFS=',' read -ra SPAWN_LIST <<< "$SPAWNS"

for mode in "${MODE_LIST[@]}"; do
  export BENCH_MODE="$mode"
  for spawn in "${SPAWN_LIST[@]}"; do
    login=0; [[ "$spawn" == login ]] && login=1
    local_tag="${mode}.${spawn}"
    ui rule "mode=$mode  spawn=$spawn"
    declare -a RUNENV; mapfile -t RUNENV < <(mk_runenv "$mode")

    # ---- fish ----
    if has_target fish && [[ -n "$FISH_WRAP$DRYRUN" ]]; then
      fb="${FISH_WRAP:-/dry}/bin/fish"
      lbl="fish.${local_tag}"
      want_tier coarse  && tier_coarse  "$lbl" "$fb" "$login" "${RUNENV[@]}"
      want_tier metrics && tier_metrics "$lbl" "$fb" "$login" "$FISH_PROMPT_REGEX" "${RUNENV[@]}"
      want_tier syscall && tier_syscall "$lbl" "$fb" "$login" "${RUNENV[@]}"
      if want_tier attrib; then
        tier_profile_fish "$lbl" "$fb" "${RUNENV[@]}"
        [[ -n "$FISH_WRAP" && -n "$FISH_UNWRAP" ]] && \
          tier_ablation_fish "$lbl" "$FISH_WRAP" "$FISH_UNWRAP/bin/fish" "${RUNENV[@]}"
      fi
    fi

    # ---- bash: pure (BASH_NO_FISH=1) AND real handoff (execs fish) ----
    if has_target bash && [[ -n "$BASH_WRAP$DRYRUN" ]]; then
      bb="${BASH_WRAP:-/dry}/bin/bash"
      # pure bash
      declare -a BENV_PURE=("${RUNENV[@]}" "BASH_NO_FISH=1")
      lbl="bash-pure.${local_tag}"
      want_tier coarse  && tier_coarse  "$lbl" "$bb" "$login" "${BENV_PURE[@]}"
      want_tier metrics && tier_metrics "$lbl" "$bb" "$login" "" "${BENV_PURE[@]}"
      want_tier syscall && tier_syscall "$lbl" "$bb" "$login" "${BENV_PURE[@]}"
      # real handoff bash -> fish (what a terminal actually does)
      lbl="bash-handoff.${local_tag}"
      want_tier coarse  && tier_coarse  "$lbl" "$bb" "$login" "${RUNENV[@]}"
      want_tier metrics && tier_metrics "$lbl" "$bb" "$login" "$FISH_PROMPT_REGEX" "${RUNENV[@]}"
      want_tier syscall && tier_syscall "$lbl" "$bb" "$login" "${RUNENV[@]}"
    fi
  done
done

# ---- devshell (coarse only; its 'startup' is nix-eval-bound, not rc-bound) --
if has_target devshell && want_tier coarse && [[ $DRYRUN == 0 ]]; then
  log "T1 coarse: devshell (nix develop ${FLAKE}#default --command true) [warm]"
  pin hyperfine --warmup "$WARMUP" --runs "$WARMUP" --shell=none \
    --export-json "$OUTDIR/devshell.coarse.json" -- \
    "nix develop ${FLAKE}#default --command true" >/dev/null 2>&1 \
    || warn "devshell coarse failed (first eval can be slow / needs network)"
fi

ui panel "done" "results: $OUTDIR
summaries: python3 bench/stats.py summarize $OUTDIR/*.metrics.json
compare:   python3 bench/stats.py compare A.metrics.json B.metrics.json"
log "Done. Results in $OUTDIR"
