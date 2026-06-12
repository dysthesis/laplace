# Shell startup & latency benchmark

A standardised, reproducible way to measure — and then optimise — the startup
and interactive latency of the shells this flake builds (`pkgs.configured.fish`,
`pkgs.configured.bash`, and the `nix develop` devShell).

> **Status:** validated end-to-end on phobos against `configured.fish`
> (`nix run .#bench -- --targets fish --tiers coarse,metrics,syscall`). The PTY
> harness produces stable, internally-consistent numbers (its `exit_time`
> matches an independent `fish -i -c exit`). Treat absolute values as
> machine-and-load-dependent; the harness is built for **relative** comparison
> (A/B, ablation, regression), which is where it is trustworthy.

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

| Metric              | Definition                             | What it exposes in _this_ config                                                                                                                                            |
| ------------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `first_prompt_lag`  | spawn → prompt fully painted           | the cost of `user_config.fish`: `starship init`, `zoxide init`, `direnv hook`, plugin loads, **`dbus-update-activation-environment`**, **`task … next`**                    |
| `first_command_lag` | spawn → first command starts executing | same, but the number that matters for "open tab, immediately type"                                                                                                          |
| `command_lag`       | Enter on an empty line → next prompt   | **starship prompt render every Enter**: `custom.taskwarrior` (forks `task` + `which`), `git_metrics`, `git_status`, `git_branch`, `battery`, `memory_usage`, `cmd_duration` |
| `input_lag`         | one keypress → character echoed        | fish's built-in syntax highlighting + `autopair`, recomputed per keystroke                                                                                                  |
| `input_lag_longbuf` | same, with a long line already typed   | the full-buffer re-highlight cost the second write-up calls out — worst case for a long command line                                                                        |
| `exit_time`         | `fish -i -c exit` wall-clock           | **the "wrong" metric** — kept only as a labelled floor and a cheap regression tripwire, never the headline                                                                  |

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
   `--profile-startup` ranks init lines by self-time, _and_ an ablation sweep
   rebuilds the config minus each suspect line and measures the delta. If the
   profiler and the ablation disagree, you've found a second-order effect.
4. **Variants are clean.** Want to know what removing `task … next` buys? The
   ablation tier already answers it; an A/B of two whole store paths
   (`--ab A B`) answers it for any pair of builds.

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
  - _isolated_: fresh `$HOME` and a fresh tmpfs `XDG_RUNTIME_DIR` (so fish's
    tmpfs-redirected config — see `user/wrapped/fish/fish-on-tmpfs.patch` —
    starts empty and reproducible), real `$PATH` kept (the shell still needs to
    exec `starship`/`task`/`git`). Use this for A/B and regression gating.
  - _in-situ_: your real session, real dbus, real Taskwarrior DB, real history.
    This is the ground truth for "how does phobos feel right now", but noisy and
    non-reproducible. **Isolated ≠ in-situ on purpose**: the init forks
    `dbus-update-activation-environment` and `task … next`, whose cost depends
    on external state the isolated regime deliberately flattens.
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

- **External state**: `task` DB size and dbus responsiveness move in-situ
  numbers. `task count` is 0 today; it will grow. Re-baseline periodically.
- **Cold vs warm cache**: the harness reports **warm** (after `--warmup`).
  Cold-cache (post-reboot / post-GC) startup is worse; dropping caches needs
  root (`vm.drop_caches`) and is intentionally not done automatically.
- **CPU governor / turbo**: recorded, not controlled. Pin a core with `--core`
  and ideally set a fixed governor before a serious A/B.
- **Terminal-emulator latency is out of scope.** Ghostty/foot/wezterm add their
  own input latency (the first write-up notes this). This harness isolates the
  _shell_; measure the emulator separately (e.g. a typometer-style tool).
- **PTY heuristics** (below) approximate "prompt ready" and "command started".

## Limitations of the harness

- "Prompt ready" = either the `--prompt-regex` matched (default `(◎|○)`, the
  starship `[character]` symbols from `starship.toml`) **or** output went quiet
  for `--quiesce-ms`. A prompt that keeps redrawing asynchronously can fool the
  quiescence path; prefer the regex when you know the prompt's tail.
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
- **`execve` count is the cheapest attribution.** A fresh interactive fish here
  spawns ~13 processes (T4); each `tool init` / `task` / dbus round-trip is one
  fork. Cutting forks is usually the biggest startup win.

## Visual status

When run via `nix run .#bench`, the pinned python ships [`rich`](https://github.com/Textualize/rich):
`pty-probe.py` shows live **progress bars** per metric group (to stderr, so
stdout stays pure JSON), `stats.py` renders **coloured result tables** (green =
faster, red = slower in A/B), and `shell-bench.sh` prints run-plan and
mode/spawn banners via `ui.py`. All of it degrades to plain text when `rich`
isn't importable, so `python3 bench/stats.py …` still works from a bare python.

## Usage

```sh
# Everything, isolated + in-situ, on the current host:
nix run .#bench -- --modes isolated,in-situ

# Just fish, just attribution (profiler + ablation):
nix run .#bench -- --targets fish --tiers attrib

# Pin to a core, more samples, both spawn modes:
nix run .#bench -- --core 2 --runs 30 --iters 50 --spawns interactive,login

# See the plan without building/running anything:
nix run .#bench -- --dry-run

# A/B two builds (e.g. current vs a branch's fish):
nix run .#bench -- --ab /nix/store/…-fish-A/bin/fish /nix/store/…-fish-B/bin/fish

# Re-summarise raw results later:
python3 bench/stats.py summarize bench/results/<ts>/*.metrics.json
python3 bench/stats.py compare  base.metrics.json variant.metrics.json
```

Output lands in `bench/results/<timestamp>/`: per-target `*.metrics.json` (raw
samples), `*.coarse.json` (hyperfine), `*.profile-top.txt`, `abl/*.compare.json`
(ablation deltas), `*.strace.txt`, and `provenance.json`.

## Suggested optimisation loop

1. `--tiers metrics` to get the perceptual baseline (median + CI per metric).
2. `--tiers attrib` to attribute: the profiler ranks init lines; ablation
   quantifies each suspect's true delta. Prime suspects already visible:
   `dbus-update-activation-environment`, the startup `task … next`, and (for
   `command_lag`) starship's `custom.taskwarrior` + git modules.
3. Make one change (e.g. lazy-load a `tool init`, drop a synchronous fork, trim
   a starship module).
4. Re-run with `--ab` against the previous store path. Keep it only if the delta
   CI excludes 0 and Mann-Whitney agrees.
5. Repeat. Optimise the metric you feel (`first_command_lag`, `command_lag`,
   `input_lag`), not `exit_time`.

## A note on prompt cost

`command_lag` is dominated by the **synchronous** work the prompt does on every
Enter. `starship.toml` here renders `custom.taskwarrior` (which forks `task` and
`which`), `git_metrics`, `git_status`, and `git_branch` among others. To A/B the
prompt specifically, point `STARSHIP_CONFIG` at a trimmed TOML and re-run the
`command_lag` measurement in-situ inside a large repo (where git work is most
expensive) — that is the per-Enter lag the second write-up warns about.
