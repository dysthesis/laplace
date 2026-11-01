# Shell startup & latency benchmark

A standardised, reproducible way to measure — and then optimise — the startup
and interactive latency of the shells this flake builds (`pkgs.configured.fish`,
`pkgs.configured.bash`, and the `nix develop` devShell).

> **Status:** previously validated end-to-end on phobos against `configured.fish`
> (`nix run .#bench -- --targets fish --tiers coarse,metrics,syscall`). A
> deimos-specific, private-bus PTY experiment is recorded below. Absolute values
> depend on machine and load; compare interleaved variants at the same boundary.

## Why not just `time fish -i -c exit`?

Because it measures the wrong thing. This is the central correction in the two
write-ups that motivated this harness
([life is too short for a slow terminal](https://mijndertstuij.nl/posts/life-is-too-short-for-a-slow-terminal/),
[what I got wrong about fast terminals](https://mijndertstuij.nl/posts/what-i-got-wrong-about-fast-terminals/)):

`time fish -i -c exit` reports **total init + teardown** of a shell that
immediately kills itself. That is not what you wait on. What you actually feel
is (a) how fast a prompt appears in a new tab, (b) how fast you can run the
first command, (c) the pause after pressing Enter, and (d) per-keystroke lag.
[zsh-bench](https://github.com/romkatv/zsh-bench#how-not-to-benchmark) makes the
same point and defines the metrics that _do_ correlate with perception. A config
can be slow on the `exit`-time number yet feel instant (e.g. with an instant /
transient prompt), and vice-versa.

zsh-bench only drives zsh. Our daily driver is **fish**, so this harness
re-implements zsh-bench's _method_ (a pseudo-terminal that injects keystrokes
and timestamps reactions) for an arbitrary shell binary.

## What gets measured

| Metric              | Definition                             | What it exposes in _this_ config                                                                               |
| ------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `first_prompt_lag`  | spawn → prompt rendered                | Fish vendor init, build-time generated hooks, D-Bus import, and the first Starship render                      |
| `first_command_lag` | spawn → first command starts executing | same, but the number that matters for "open tab, immediately type"                                             |
| `command_lag`       | Enter on an empty line → next prompt   | full Starship redraw (`custom.jj` via `jj log`, Git modules, sudo and right prompt); `custom.task` is disabled |
| `input_lag`         | one keypress → character echoed        | fish's built-in syntax highlighting + `autopair`, recomputed per keystroke                                     |
| `input_lag_longbuf` | same, with a long line already typed   | the full-buffer re-highlight cost the second write-up calls out — worst case for a long command line           |
| `exit_time`         | `fish -i -c exit` wall-clock           | **the "wrong" metric** — kept only as a labelled floor and a cheap regression tripwire, never the headline     |

## Why this is more than the blog's approach

The write-ups measure ambient binaries with `time` and `hyperfine`. Because this
is a Nix flake, we can do better and be **reproducible to the store hash**:

1. **Benchmark the exact artifact.** The script resolves and builds
   `nixosConfigurations.<host>.pkgs.configured.fish` etc. and runs _that_ store
   path — not whatever `fish` happens to be on `$PATH` (on a headless checkout
   there is none). Two configs to compare = two store paths.
2. **Provenance is recorded** (`provenance.json`): store hashes, git rev + dirty
   flag, kernel, CPU governor, load average, and tool versions. A result you
   can't attribute to an input is not a measurement.
3. **Attribution is cross-validated two ways** (tier T3): fish's native
   `--profile-startup` ranks init lines by self-time, and an ablation sweep
   comments matching lines in a copy of the generated vendor config. The
   ablation needs a correctly isolated bus if init publishes session variables.
4. **Variants are clean.** A/B of two whole store paths (`--ab A B`) compares
   separate Fish builds; direct `pty-probe.py` also accepts either executable.

## Tiers

| Tier                  | Script path                                | Tool                               |
| --------------------- | ------------------------------------------ | ---------------------------------- |
| T0 provenance         | `lib.sh:capture_provenance`                | `nix`, `jq`, sysfs                 |
| T1 coarse floor       | `shell-bench.sh:tier_coarse`               | `hyperfine`                        |
| T2 perceptual metrics | `pty-probe.py`                             | stdlib PTY                         |
| T3 attribution        | `tier_profile_fish` + `tier_ablation_fish` | `fish --profile-startup`, ablation |
| T4 syscall/exec       | `tier_syscall`                             | `strace -f -c`                     |
| T5 A/B compare        | `run_ab` + `stats.py compare`              | bootstrap CI + Mann-Whitney        |

## Regimes and spawn modes

- **`--modes isolated,in-situ`**
  - _isolated_: fresh `$HOME` and `XDG_RUNTIME_DIR` (fish's config directory
    follows the latter; see `user/wrapped/fish/fish-on-tmpfs.patch`), real
    executable `$PATH`. This isolates history but **does not isolate D-Bus**:
    `DBUS_SESSION_BUS_ADDRESS` remains inherited unless the entire experiment
    runs under a private bus (e.g. `dbus-run-session`).
  - _in-situ_: the real user session, D-Bus activation environment, history and
    Atuin state. The Fish wrapper publishes `--all` on every interactive shell;
    first-command probes can be saved to history and uploaded to the user bus.
    Use only with explicit privacy and session-side-effect review.
- **`--spawns interactive,login`** — `user_config.fish` branches on both
  (`status is-login` sources `/etc/profile` via `fenv`; `status is-interactive`
  does the heavy lifting). A new tmux pane is interactive-non-login; the first
  shell of a session is login. Measure both.
- **bash is measured twice.** `configured.bash`'s rcfile `exec`s fish on
  interactive use unless `BASH_NO_FISH=1` (`user/wrapped/bash/default.nix`). So
  the harness runs `bash-pure` (`BASH_NO_FISH=1`, bash's own startup) and
  `bash-handoff` (the real bash→fish chain a terminal triggers).

## Statistics

Startup distributions are right-skewed (GC pauses, scheduler stalls, cache
misses), so `stats.py` reports the **median** with:

- **MAD** (median absolute deviation, σ-scaled) for spread,
- **p90 / p99** for the tail you occasionally feel,
- a **nonparametric bootstrap 95 % CI** of the median.

A/B comparison reports the **delta of medians**, a **bootstrap CI of that
delta**, and a **tie-corrected Mann-Whitney U** p-value. A change is flagged
significant (`*`) only when the median moved **and** the delta CI excludes 0
**and** p < 0.05. A/B spawns are **interleaved** (A,B,A,B), never batched, so
slow drift in machine state cancels instead of biasing one arm.

## Threats to validity (read before quoting a number)

- **External state**: D-Bus responsiveness and repository size affect prompt
  timings. The configured Taskwarrior prompt module is disabled; Taskwarrior
  data does not explain these measurements.
- **Cold vs warm cache**: `--warmup` applies to `hyperfine`'s coarse tier,
  **not** the PTY tier. Run separate PTY warmups before comparing warm trials.
  No cache dropping or post-reboot measurement is performed automatically.
- **CPU governor / turbo**: recorded, not controlled. Pin a core with `--core`
  and ideally set a fixed governor before a serious A/B.
- **Terminal-emulator latency is out of scope.** Ghostty/foot/wezterm add their
  own input latency (the first write-up notes this). This harness isolates the
  _shell_; measure the emulator separately (e.g. a typometer-style tool).
- **PTY heuristics** (below) approximate "prompt ready" and "command started".

## Limitations of the harness

- "Prompt ready" = either `--prompt-regex` matches or output goes quiet for
  `--quiesce-ms`. `shell-bench.sh` still passes the legacy `(◎|○)` regex,
  whereas this Fish prompt uses `❯`/`❮`; it therefore falls back to quiescence.
  For full-prompt timing explicitly use `--prompt-regex ''` with `pty-probe.py`;
  a glyph regex may match before Starship finishes the right prompt.
- `first_command_lag` types a sentinel command immediately and times until its
  _executed output_ appears. The sentinel is passed via `$BPROBE_MARK` so the
  typed text never collides with the output. For a near-instant `printf` this
  approximates "command started" to within its own runtime.
- These mirror what zsh-bench itself acknowledges as hard. **Validate on the
  first real run**: eyeball a recording (`script -c …`) and confirm the numbers
  track reality before optimising against them.

Lessons already baked in from validating against fish:

- **The harness answers terminal queries.** fish and starship emit DA1/DA2,
  CPR/DSR, OSC 10/11 colour, XTVERSION, XTGETTCAP and kitty-keyboard probes at
  startup and _block_ reading the reply. A dumb PTY has no emulator on the far
  end, so without canned answers the shell consumes your keystrokes as the reply
  and never reaches its line editor. `pty-probe.py` replies like a minimal real
  terminal (`_QUERY` / `_reply_for`). If you benchmark a shell that emits a
  probe we don't answer, it will hang to the timeout — add it there.
- **Raw mode + settle** isolate the shell's _rendered_ echo from the kernel's
  instant echo and from pending redraw bytes. Without this, `input_lag`
  collapses to ~0 (kernel echo) or to a stale match. Exception: readline
  samples the termios ECHO flag at startup and _suppresses its own echo_ when
  it is off, so readline shells (bash) must be probed with `--no-raw` (the
  harness does this for `bash-pure`) or every keystroke times out.
- **`command_lag` quiesces on the full render.** A starship prompt arrives in
  several bursts (transient repaint, clear, full prompt) whose internal gaps
  reach tens of ms; the quiesce window for this metric therefore matches
  `--quiesce-ms` (default 120 ms), well past any inter-burst gap. The recorded
  time is the _last byte's_ arrival, so the window itself doesn't inflate the
  number — but a too-small window randomly clocks an intermediate burst and
  bimodalises the metric.
- **`input_lag_longbuf ≈ input_lag`** for fish, because fish re-highlights
  _incrementally_; appending a keystroke is cheap regardless of line length.
  This is unlike the zsh-syntax-highlighting plugin the second write-up
  criticises, which re-highlights the whole buffer. Don't expect the long-line
  blow-up here — that critique is zsh-plugin-specific.
- **Module timing is not PTY latency**: `starship timings` ranks modules within
  one render, but the PTY figures include Fish redraw and the right prompt.

## Visual status

When run via `nix run .#bench`, the pinned python ships [`rich`](https://github.com/Textualize/rich):
`pty-probe.py` shows live **progress bars** per metric group (to stderr, so
stdout stays pure JSON), `stats.py` renders **coloured result tables** (green =
faster, red = slower in A/B), and `shell-bench.sh` prints run-plan and
mode/spawn banners via `ui.py`. All of it degrades to plain text when `rich`
isn't importable, so `python3 bench/stats.py …` still works from a bare python.

## Usage

```sh
# Run all checks in isolated and current-session environments.
nix run .#bench -- --modes isolated,in-situ

# Measure Fish startup costs with the profiler and ablation.
nix run .#bench -- --targets fish --tiers attrib

# Use one CPU core and more samples in the two spawn modes.
nix run .#bench -- --core 2 --runs 30 --iters 50 --spawns interactive,login

# Show the plan without builds or measurements.
nix run .#bench -- --dry-run

# Compare two Fish builds.
nix run .#bench -- --ab /nix/store/…-fish-A/bin/fish /nix/store/…-fish-B/bin/fish

# Calculate statistics from saved results.
python3 bench/stats.py summarize bench/results/<ts>/*.metrics.json
python3 bench/stats.py compare  base.metrics.json variant.metrics.json
```

Output lands in `bench/results/<timestamp>/`: per-target `*.metrics.json` (raw
samples), `*.coarse.json` (hyperfine), `*.profile-top.txt`, `abl/*.compare.json`
(ablation deltas), `*.strace.txt`, and `provenance.json`.

## Deimos Fish prompt experiment (2026-09-29)

**Boundary and provenance.** On deimos (Wayland/dwl, kernel 6.18.54,
`powersave` governor), `foot` is configured to start `pkgs.configured.fish`.
The old built wrapper is
`/nix/store/b389sy78mpx9vkzdxh340ivjacg7grng-fish-wrapped/bin/fish`;
the changed wrapper is
`/nix/store/affyy36qk4z6v7y3fgkvnrr28db34cfq-fish-wrapped/bin/fish`.
Their generated vendor configs differ only in `STARSHIP_CONFIG`: the old
stored TOML matched the pre-change tracked source byte-for-byte,
and the new stored TOML and current source share a SHA-256 hash. This is
**Fish in a PTY**, not foot's visible window, compositor, login or phobos.

For the H1/H2 ablations, the raw JSON records the old build's **unwrapped**
Fish binary under each arm's label. The intended control used scratch copies
of its generated vendor config in `XDG_DATA_DIRS`, varying the named line/TOML
per arm. Those scratch configs/scripts were not retained, so the archived
labels cannot verify the exact bytes of each ablation control. The archived
`*.warmup.json` files record two warmup spawns per arm/group, followed by six
alternating A/B and B/A pairs of two spawns each (12 shells per arm for first
prompt, and a separate 12 for first command). Each first-prompt shell supplied
three Enter samples, so 36 repeated-command observations are **clustered in
12 shells**, not 36 independent trials. Medians/p90 below describe raw
observations;
reported CIs resample the six paired blocks, retaining each arm's two spawns
and their inner samples together. Independently enumerating all 6⁶ paired
block resamples from the raw JSON gave CI bounds within 0.1 ms of the saved
intervals. The probe used a 120x30 PTY, 120 ms quiescence and
`--prompt-regex '' --skip exit`; it times the **last rendered byte**.
`first_command_lag` instead times an immediately submitted `printf` until
its output. The original trials are labelled `private-session`, but their
JSON does not capture `$HOME`, XDG paths or the bus address: historical
isolation cannot be independently verified from the archived samples. The
reproducer below uses private history/runtime paths and `dbus-run-session`;
that bus does not reproduce the live broker/systemd activation delays.

| Context / experiment          | Metric (ms)      | Baseline median / p90 | Candidate median / p90 | Delta of medians (95% paired-block CI) |
| ----------------------------- | ---------------- | --------------------: | ---------------------: | -------------------------------------: |
| outside / no D-Bus import     | first prompt     |         51.89 / 53.17 |          50.07 / 51.84 |                   -1.81 [-3.14, -0.82] |
| empty Git / no D-Bus import   | first command    |         62.70 / 65.15 |          59.10 / 61.30 |                   -3.59 [-5.11, -2.29] |
| jj checkout / no D-Bus import | first command    |         84.65 / 87.06 |          80.31 / 83.87 |                   -4.34 [-5.26, -2.92] |
| jj checkout / one `jj log`    | first prompt     |         70.81 / 74.31 |          61.33 / 62.51 |                  -9.47 [-10.31, -8.37] |
| jj checkout / one `jj log`    | first command    |         80.11 / 83.60 |          72.56 / 74.33 |                   -7.55 [-9.71, -6.93] |
| jj checkout / one `jj log`    | repeated command |         38.24 / 40.46 |          27.79 / 29.07 |                 -10.45 [-10.88, -9.83] |
| outside / one `jj log`        | repeated command |         20.01 / 20.77 |          20.85 / 21.74 |                   +0.84 [+0.38, +1.32] |
| dirty Git / one `jj log`      | repeated command |         20.42 / 21.08 |          21.44 / 21.89 |                   +1.02 [+0.76, +1.28] |

The **no-D-Bus-import** ablation was not retained: startup savings were
roughly 2–4 ms (the first prompt was 1.81 ms faster outside, 1.91 ms in
empty Git and 2.86 ms in the jj checkout), below the predeclared 10 ms
threshold; repeated commands did not improve. Moreover, dwl's autostart
currently imports variables into `systemd --user`, **not** the D-Bus activation
environment, while `xinit` does publish to both. Dropping Fish's
`dbus-update-activation-environment --systemd --all` would require a
session-wide replacement, including nested and SSH semantics. Leave it
unchanged rather than assume the two activation environments are equivalent.

**Retained:** in `user/wrapped/fish/starship.toml`, one
`jj log --ignore-working-copy` now both probes jj membership and formats the
change; a conditional `$output` group hides `jj:` when not in a repo. This
removes the separate `jj root` fork on _every prompt in a jj repo_, with no
working-copy snapshot or cached metadata. Its repeated-command improvement
exceeded the 10 ms target; the ~1 ms outside/plain-Git regression is real,
but below the practical threshold. The previously configured `custom.task`
was already disabled; Git modules were _not_ removed. The archived
`semantic-equality.log` lists equal escaped prompts in nine contexts,
including conflicted jj. A fresh real-Starship run with the two stored TOMLs,
private HOME/XDG state and bus compared stdout/stderr byte-for-byte in eight
contexts: outside, empty/clean/dirty/conflicted Git, empty/described jj, and
this checkout. All eight matched (stderr empty); that rerun did **not**
recreate a conflicted jj repository. After the Nix build, archived PTY probes
of the actual new wrapper covered outside, dirty Git, this checkout and
conflicted jj (`bench/results/20260929-shell/built/`). Input lag stayed near
0.1 ms; no foot/compositor latency is inferred.

An independent recovery smoke launched that actual wrapped Fish with private
HOME/XDG history/runtime paths and `dbus-run-session`, exercising its first
prompt, first command and two Enter redraws in this checkout. The raw receipt
is `bench/results/retest/recovery-wrapper-smoke.json` (67.56 ms, 65.10 ms,
29.10/29.47 ms respectively); n=1/1/2 proves the path ran, not a new A/B
estimate.

The original conflicted-jj wrapper smoke recorded Enter samples of 3.15 ms
then 3122.18 ms, with `ignore_timeout = true` unchanged. Their cause is
**unknown**: neither a confirmed 3-second prompt regression nor a trustworthy
fast render follows from those two values. A separate interleaved A/B in one
disposable _actually conflicted_ jj merge traced every PTY output chunk after
the prompt settled (120 ms quiet window): 36 Enter redraws per real wrapper,
old median/p90/max 36.47/38.52/40.30 ms, new 25.78/27.26/27.70 ms.
All 72 redraws settled and contained the `=conflict` prompt; none took <5 ms
or >1 s. This bounds the observed tail in that fixture, not the cause or
recurrence rate of the earlier 3.12 s event. Timing arrays, the slowest
per-arm full-prompt chunk bytes, and the fixture recipe are in
`bench/results/fish-20260929-evidence.json`; the full 72-event chunk trace
is local-only under `bench/results/retest/conflict-tail-trace.json`.

In a **second A/B using the actual old/new Nix-built Fish wrappers**, six
reversed-order pairs in the jj checkout measured first prompt 67.80 → 56.96 ms
(p90 70.11 → 60.00; delta -10.84, paired CI [-13.15, -8.59]),
first command 77.51 → 66.66 ms (p90 79.09 → 68.94; -10.86,
[-11.12, -8.80]), and repeated command 38.92 → 28.37 ms
(p90 41.90 → 29.83; -10.55, [-11.04, -10.17]). Each arm had 12 separate
spawns for each startup metric; the 36 Enter timings per arm came three
apiece from 12 shells. Per-spawn median Enter lags changed by -10.22 ms.
Original wrapper retest pairs, pair order and paired-block CIs remain as
local-only raw runs in `bench/results/retest/`; a compact durable receipt of
the paired samples, exact store/config identity, and follow-up protocol is
`bench/results/fish-20260929-evidence.json`. The wrapper retest's warmup
output was discarded, so its historical warmup count, `$HOME`/XDG state, bus
address and exact `$PATH` cannot be independently checked from the raw JSON.
Do not retroactively assign the later private-session environment to it.
The reproduction below saves its _own_ warmups and allowlisted environment
per run. These are warm-use PTY results, not boot-cold starts.

The historical A/B applies to those _exact_ `b389…` → `affyy…` wrappers, not
automatically to the latest output of this checkout. A final offline
evaluation/build of `pkgs.configured.fish` for **deimos and phobos** resolved
the same `/nix/store/v2g7hjz1a0n5bq9prd3j0fv4phhqqh5g-fish-wrapped`;
its `STARSHIP_CONFIG` still points to the tested TOML (SHA-256
`97691ca5cd3e9b1b2359dce1fc356d790ce983b7118b0739da5c205dd3bd45ac`).
Its direnv configuration now also sets `hide_env_diff = true`, an unrelated
effective behavior change. A private-bus PTY smoke of the _current_ wrapper
in this checkout gave first prompt 64.84 ms, first command 61.71 ms, and
Enter redraws 26.91/26.24 ms (n=1/1/2): this proves the current path runs,
**not** a current-build A/B or a transferred latency estimate.

**Follow-up rejected:** `git_status` still costs time in colocated jj repos,
but `jj log --ignore-working-copy` cannot replace its Git working-tree status:
the nonempty jj fixture showed `!1` and the conflicted fixture showed `=1`.
Suppressing it would lose useful state, not just duplicate work. `sudo`
also appeared in single-render timing, but is deliberately configured to
show cached credentials; no equivalent cheaper status path was established.

Historical H1/H2 raw samples, A/B summaries and per-arm statistics under
`bench/results/20260929-shell/` are ignored by Git. The ablation scratch
inputs are gone; they are exploratory context, **not** audited reproducible
controls. The committed receipt covers the real-wrapper retest instead.
`python3 bench/stats.py compare` on locally retained merged JSON reproduces
medians, **but** its CI/p-value resamples 36 Enter observations as if
independent; use paired-block resampling for the CI.

The real-wrapper retest's six paired blocks can be enumerated directly from
the committed receipt; for repeated-command lag, exact 6⁶-block resampling
produces [-11.03, -10.16] ms (the original `paired.json` bootstrap reports
[-11.04, -10.17] ms):

```sh
python3 - <<'PY'
import json
from itertools import product
from pathlib import Path
from statistics import median

receipt = Path("bench/results/fish-20260929-evidence.json")
pairs = json.loads(receipt.read_text())["paired_checkout"]["pairs"]
runs = {arm: [pair[arm]["command_lag_ms"] for pair in pairs]
        for arm in ("old", "new")}
def delta(blocks):
    return median(x for p in blocks for x in runs["new"][p]) - median(
        x for p in blocks for x in runs["old"][p])

values = sorted(delta(blocks) for blocks in product(range(6), repeat=6))
def percentile(q):
    pos = (len(values) - 1) * q / 100
    lo = int(pos)
    return values[lo] + (values[min(lo + 1, len(values) - 1)] - values[lo]) * (pos - lo)

print(f"exact paired-block 95%: [{percentile(2.5):.2f}, {percentile(97.5):.2f}] ms")
PY
```

To repeat with two _real_ wrapped Fish builds, use `nix build --no-link
--print-out-paths '.#nixosConfigurations.deimos.pkgs.configured.fish'` before
and after changing the source, then substitute those `/bin/fish` paths for
`OLD` and `NEW` below. Set `REPO` to this checkout's **absolute** path (the
example is deimos-specific). Run the entire block from the directory being
measured: `CONTEXT=checkout` for the checkout, then change that value to
`outside` and run from a plain directory outside every jj/Git worktree.
Each invocation creates a unique `results/retest/<context>/run.*` directory;
the original `retest/{1..6}.{old,new}.json` cannot be overwritten. The
explicit outer Bash and subshell confine HOME/XDG exports; the nested Bash
runs under a disposable bus. No live user bus or desktop is contacted.

```bash
env -i \
  PATH="/nix/store/l25gq3dqifhzbhsvr7cl3vl7h0kzrwai-python3-3.14.7/bin:/etc/profiles/per-user/demiurge/bin:/run/current-system/sw/bin" \
  REPO="/home/demiurge/Documents/Projects/laplace" CONTEXT=checkout \
  /run/current-system/sw/bin/bash <<'BASH'
set -euo pipefail
(
  [[ $REPO = /* && -f $REPO/bench/pty-probe.py ]] || exit 2
  [[ $CONTEXT =~ ^[a-z0-9-]+$ ]] || exit 2
  MEASURE_CWD=$(pwd -P)
  PROBE="$REPO/bench/pty-probe.py"
  mkdir -p "$REPO/bench/results/retest/$CONTEXT"
  RESULTS=$(mktemp -d "$REPO/bench/results/retest/$CONTEXT/run.XXXXXXXX")
  SANDBOX=$(mktemp -d)
  trap 'rm -rf -- "$SANDBOX"' EXIT
  mkdir -p "$SANDBOX/home" "$SANDBOX/run"
  export HOME="$SANDBOX/home" XDG_RUNTIME_DIR="$SANDBOX/run"
  export XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$HOME/.local/state"
  export XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
  export XDG_DATA_DIRS=/run/current-system/sw/share TERM=xterm-256color LC_ALL=C.UTF-8
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  OLD=/nix/store/b389sy78mpx9vkzdxh340ivjacg7grng-fish-wrapped/bin/fish
  NEW=/nix/store/affyy36qk4z6v7y3fgkvnrr28db34cfq-fish-wrapped/bin/fish
  export OLD NEW PROBE RESULTS MEASURE_CWD CONTEXT
  dbus-run-session -- bash <<'PRIVATE_BASH'
set -euo pipefail
cd "$MEASURE_CWD"
python3 - "$RESULTS" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys
root = Path(sys.argv[1])
env = os.environ
record = {
    "context": env["CONTEXT"], "measurement_cwd": os.getcwd(),
    "repo": env["REPO"],
    "environment": {key: env[key] for key in (
        "PATH", "TERM", "LC_ALL", "XDG_DATA_DIRS", "GIT_CONFIG_GLOBAL",
        "GIT_CONFIG_NOSYSTEM")},
    "private_home_xdg": all(env[key].startswith(str(Path(env["HOME"]).parent))
                            for key in ("HOME", "XDG_RUNTIME_DIR",
                                        "XDG_CONFIG_HOME", "XDG_STATE_HOME",
                                        "XDG_DATA_HOME", "XDG_CACHE_HOME")),
    "private_bus": bool(env.get("DBUS_SESSION_BUS_ADDRESS")),
    "versions": {name: subprocess.check_output(command, text=True).splitlines()[0]
                 for name, command in {
                     "python": ["python3", "--version"],
                     "jj": ["jj", "--version"], "git": ["git", "--version"],
                     "fish": [env["NEW"], "--version"]}.items()},
    "arms": {"old": env["OLD"], "new": env["NEW"]},
    "pairs": 6, "order": "odd old/new; even new/old",
    "warmup_spawns_per_arm": 2, "spawns_per_arm_per_pair": 2,
    "enters_per_spawn": 3, "pty": "120x30; 120ms quiet; empty prompt regex",
}
(root / "protocol.json").write_text(json.dumps(record, indent=2) + "\n")
PY
for arm in old new; do
  if [[ $arm == old ]]; then shell=$OLD; else shell=$NEW; fi
  python3 "$PROBE" --shell "$shell" --prompt-runs 2 --inner-iters 1 \
    --skip exit --prompt-regex '' >"$RESULTS/$arm.warmup.json"
done
for pair in 1 2 3 4 5 6; do
  if ((pair % 2)); then arms=(old new); else arms=(new old); fi
  for arm in "${arms[@]}"; do
    if [[ $arm == old ]]; then shell=$OLD; else shell=$NEW; fi
    python3 "$PROBE" --shell "$shell" --prompt-runs 2 --inner-iters 3 \
      --skip exit --prompt-regex '' >"$RESULTS/$pair.$arm.json"
  done
done
PRIVATE_BASH
  python3 - "$RESULTS" <<'PY'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
for arm in ("old", "new"):
    blobs = [json.loads((root / f"{pair}.{arm}.json").read_text())
             for pair in range(1, 7)]
    result = blobs[0]
    result["samples"] = {key: [x for blob in blobs for x in blob["samples"][key]]
                         for key in result["samples"]}
    (root / f"{arm}.json").write_text(json.dumps(result, indent=2) + "\n")
PY
  python3 "$REPO/bench/stats.py" compare "$RESULTS/old.json" "$RESULTS/new.json"
  printf 'Measurement cwd: %s\nRaw results: %s\n' "$MEASURE_CWD" "$RESULTS"
)
BASH
```

The Fish wrapper itself sets `STARSHIP_CONFIG`, so overriding only the
parent's environment variable does **not** test an alternate prompt. This
recipe measures _warm_ local PTY interactions with a clean allowlisted parent
environment; it omits in-situ history, live-bus publication, emulator
rendering and post-boot cold starts. `stats.py compare` prints unclustered
intervals; preserve the pair files and resample pair blocks for inference.

Running the published Bash block from this checkout and again from `/tmp`
(`CONTEXT=outside`) saved separate raw runs with private bus and HOME/XDG:
`bench/results/retest/{checkout/run.p55kbznm,outside/run.FVszeiKE}/`.
Repeated-command medians were 37.49 → 27.01 ms in checkout and
19.47 → 20.34 ms outside (six reversed-order pairs each). The checkout
smoke overlapped one short Nix evaluation near its start; it validates the
**runnable protocol**, not a new uncontended estimate. The durable receipt
records the two actual measurement directories, allowlisted environment,
versions and warmup count, rather than inventing these for historical runs.

## Deimos desktop experiment and boot boundary (2026-09-29)

**Hypothesis:** spawning the existing configured Zen wrapper directly with
`dwl`'s Super+w would save at least 100 ms over Super+r → `bemenu-run` →
typing `zen-beta` → Return. In six reversed-order pairs on private Xvfb/X11
`dwl` seats (one warmup per arm, private bus and fresh Zen profile per trial),
first non-black compositor pixels arrived at menu median 1016.3 ms versus
direct 933.6 ms: paired median saving **83.1 ms**, below the 100 ms target.
The real wrapped Zen and menu were used; the browser shortcut is retained
as an explicitly approved **ergonomic** improvement (one chord instead of
launcher/query/confirmation), **not** a successful speed experiment.

The screenshot probe sampled a 32×32 compositor region about every 44 ms;
it does not time human gestures, physical monitor scanout, full browser
readiness, the live user's warm profile or a phobos desktop. A separate
private-seat smoke of the retained Super+w binding reached Zen's first-run
Welcome UI, which did not advance on that seat. Relaunching in a new
private seat with a copy of _only_ the initialized disposable Zen profile
showed normal browser chrome and keyboard-navigable `about:about`.
The settled PNG is `bench/results/desktop-20260929-settled.png`.
`bench/results/desktop-20260929-evidence.json` retains all six pairs'
first-pixel sample timestamps, changed-pixel hashes, arm store identity and
bounded redacted primary boot/network excerpts. Full logs and screenshots
for individual trials remain local-only in `bench/results/desktop-latency/`;
the navigation proof is functional, not another comparable A/B.

Boot evidence also rejects a tempting but incorrect network shortcut:
the initrd took 29.947 s, of which the console unlock query spanned
5.320–27.698 s (22.378 s). `getty@tty1` was ready at 34.282 s before the
`priv` DHCP lease at 46.030 s and `dhcpcd` readiness at 46.172 s.
NetworkManager reported `priv` externally connected while attempting its
parent interface; there is no measured first-getty DHCP barrier and no
evidence of duplicate DHCP ownership on `priv`. No network, power or boot
setting was changed.
