# Laplace

A NixOS flake. It is a work-in-progress rewrite of my old configurations.

## Nix tooling

All hosts use the official Determinate NixOS module, constrained to major version 3.
Keep Determinate's own nixpkgs input pin so its binaries remain substitutable.
The module selects `nix.package`; Nixd manages `/etc/nix/nix.conf`, including lazy
trees, evaluator parallelism, its binary cache, and rotating signing keys.
Local `nix.settings` are written to the included `/etc/nix/nix.custom.conf`.
NixOS and binfmt supply host features and supported platforms; do not advertise
a CPU architecture globally.

`nix/overlays/nix-output-monitor.nix` backports the immutable upstream
[unknown activity/result fix](https://github.com/maralorn/nix-output-monitor/pull/321)
and makes `nh` use that monitor. Remove the backport once pinned nixpkgs includes it.

The configured direnv wrapper owns `DIRENV_CONFIG`, loads nix-direnv, and pins its
Nix executable to `config.nix.package`, including generated shell hooks.
It leaves `XDG_CONFIG_HOME` unchanged; fish needs no separate direnv configuration.
After switching the system, restart fish and run `direnv reload`.

Garbage collection intentionally retains the daily `--delete-older-than 7d`
policy, including old profile generations. Nixd's background collector is disabled
in `/etc/determinate/config.json` so only one collector is scheduled.

## Design

### Service-first fleet

`cluster/inventory.nix` is the application authority: a declared
`laplace.services.<name>.host` selects a deployable server and defaults enabled;
an absent entry deploys nothing. Recipes own the application plus its state and
secret consumers, proxy/DNS/access contributions and placement-dependent clients.
`hosts/` retains machine identity, hardware/storage provisioning and network
facilities. NixOS and Colmena share the validated model and module arguments.

Inspect it with `nix eval --json .#laplace`. `just deploy` selects all deployable
`@server` nodes, including nodes with no active applications. Build the full
selection before this cutover or a stateful relocation: `just deploy build`.

Disabling is not deleting data; moving is not copying data. Shared HTTPS is not
vhost isolation, and Colmena activation is not a fleet transaction. See the
[cluster operator guide](docs/cluster.md) for dependencies, validation, rollout,
secret preparation, decommissioning and relocation.

### Desktop composition

Configure `laplace.desktop` directly in the host's `config.nix`. It is a normal
NixOS option; a non-null value requires `"desktop"` in `laplace.profiles`.
Deimos and Phobos declare their existing components explicitly:

```nix
{lib, ...}: {
  laplace.profiles = ["desktop"];
  laplace.desktop = with lib.components; {
    server = wayland;
    wm = niri;
    shell = noctalia;
    term = foot;
    launcher = vicinae;
  };
}
```

`lib.components` contains ordinary component records, not installed packages.
They construct packages using the host's existing `pkgs`; NixOS and Colmena still
share host modules and overlays. There are no presets or separate host-selection
file. The component definitions are in `system/display/components.nix`; importing
a provider directly also works, for example
`wm = import ../../system/display/servers/wayland/compositors/niri;` from a host
directory.

The `server`, `wm` and `term` fields are required, including for legacy desktops
without a terminal-consuming user. Validation checks terminal metadata without
invoking its package builder. `shell`, `bar` and `launcher` default to null, but a
selected WM may require them:

| Configuration                                | Component choices beyond `server = wayland; term = foot;`       |
| -------------------------------------------- | --------------------------------------------------------------- |
| Niri with Noctalia                           | `wm = niri; shell = noctalia; launcher = vicinae;`              |
| Niri with Noctalia and external Waybar       | Add `bar = waybar;` to the row above                            |
| Standalone Niri                              | `wm = niri; bar = waybar; launcher = fuzzel;`                   |
| Existing custom Hyprland, Sway, River or dwl | Select that `wm`; leave shell, bar and launcher null            |
| Existing XMonad                              | `server = xorg; wm = xmonad;` with shell, bar and launcher null |

Waybar is a bar, not a replacement for Noctalia's notification, wallpaper and idle
services. `shell = noctalia; bar = waybar;` disables Noctalia's bars after saved
settings are applied, including per-monitor overrides. Other saved settings
remain effective and are not rewritten by the bar policy. Standalone Niri keeps
its existing Dunst and swaybg services. There is no independent notification selector.

Only the Foot terminal adapter is currently implemented; Ghostty is not a
selectable component yet. Integrated Niri requires Vicinae's application and
clipboard-history operations, while standalone Niri uses Fuzzel. Unsupported
component roles/combinations and mismatched server/WM protocols are rejected.
Legacy compositor bindings retain their own defaults and startup mechanisms;
they do not acquire native Sway integration or new cross-component support.
Independent configured Foot uses and WezTerm `imgcat` remain available.
Terminal launch arguments remain literal when Fuzzel starts terminal applications.

Component selection follows ordinary NixOS option priorities. To replace a
complete selection from another module, wrap the complete component record in
`lib.mkForce`.
The schema imports stay static; only selected component functions contribute
configuration. This avoids a `config`-dependent import graph or a second evaluator.

`config.laplace.wm` is a typed, read-only **result**, not a selection option. It is
either null or `{ protocol; login; logout; }`, with `logout = null` where no
external control operation is consumed. Operations are non-empty argument
vectors with an absolute executable, not shell command strings. Equal operation
declarations coalesce; conflicting vectors are rejected rather than concatenated.
Bash uses the
complete login vector under the existing desktop-profile, empty-`DISPLAY`, VT1
guard. It adds no compositor flags. Niri supplies configured `niri-session` for
the login context; native Niri integration owns environment import, waiting and
shutdown. Session components wait for Niri's native readiness notification before
using its imported display and IPC environment. Noctalia receives raw Niri logout
IPC separately to avoid a configured Niri/Noctalia dependency cycle.

Configured login and interactive shells are registered in `/etc/shells`, retaining
Polkit's shell validation. Vicinae keeps launched applications alive across a
launcher restart; its private extension runtime exits when the server's IPC pipe
closes, so that runtime cannot leak into the next session.

`laplace.desktop = null` (the default) contributes no managed session or
session-bound services. Use `lib.mkForce null` to disable a selection defined by
another module. Shared desktop-profile services and GTK portals remain; Chaos's
upstream GNOME installer is an external desktop, not a headless host. Null
selection does not remove home data, independent packages or previous generations.
`laplace.wm` remains read-only and cannot be used to override provider selection.

Build before activation:

```sh
nix build --no-link --no-write-lock-file \
  .#checks.x86_64-linux.desktop-stack \
  .#checks.x86_64-linux.niri-config \
  .#checks.x86_64-linux.fuzzel-terminal \
  .#checks.x86_64-linux.mk-wrapper
nix build --no-link --no-write-lock-file \
  .#nixosConfigurations.deimos.config.system.build.toplevel \
  .#nixosConfigurations.phobos.config.system.build.toplevel
```

The graphical VM also needs KVM and an EGL render node. With an `opengl` builder
that exposes `/dev/dri`, build `.#checks.x86_64-linux.desktop-session`.
Without such a sandbox, run the same driver as an unprivileged user with render
node access; it controls only its disposable guest:

```sh
nix build --no-write-lock-file --out-link /tmp/laplace-desktop-session \
  .#checks.x86_64-linux.desktop-session.driver
proof=$(mktemp -d /tmp/laplace-desktop-session.XXXXXX)
mkdir -m 700 "$proof/runtime"
XDG_RUNTIME_DIR="$proof/runtime" \
  /tmp/laplace-desktop-session/bin/nixos-test-driver -o "$proof"
```

From a running Niri terminal, the optional real-terminal regression uses disposable
notes, genuine Foot/Neovim/zk and a local bare Git remote; it does not activate a
generation or contact the user's note repository:

```sh
nix build --impure --out-link /tmp/laplace-terminal-check --expr '
  let f = builtins.getFlake (toString ./.);
  in import ./nix/tests/terminal-helpers.nix {
    pkgs = f.nixosConfigurations.phobos.pkgs;
  }'
python3 nix/tests/terminal-helpers.py /tmp/laplace-terminal-check
```

Checks cover selected configuration validation, provider removal, service
ownership and operation boundaries. `fuzzel-terminal` launches a real terminal
application under a headless compositor, including literal quoting characters.
`desktop-session` boots a disposable graphical VM using the production display
modules, Phobos's component selection plus Waybar, and a test account/password.
It exercises the VT2 guard, VT1 login, environment import, logout/re-login,
notification ownership, Waybar title/workspace interactions, barless Noctalia
panels, launcher-restart application survival, graphical authentication,
lock/unlock and the GTK file-chooser portal.
Screenshots are retained in the check or driver output; the workstation is not
activated and production calendar credentials are unavailable to the VM.

VM acceptance does not establish physical GPU/monitor/input behaviour, hardware
authentication, suspend/resume or screencasting. An authorised desktop rollout
still needs saved work, a recovery console and the previous bootable generation.
A generation switch is not an atomic live desktop replacement; use logout/login
or reboot and roll back if the hardware-specific checks fail.

The existing Xorg/gungnir build limitation remains. Capture and journal helpers
still treat every non-zero terminal/editor result as cancellation; capture also
retains its existing note-creation error policy. Dependency extraction does not
repair or conceal those inherited limitations.

### Wrappers as configurations

Instead of symlinking configuration files to their appropriate directories, _e.g._ `~`, we instead

- package configuration files with Nix,
- place them on the `/nix/store`, and
- wrap our binaries to point them to their appropriate configuration files.

Almost all programs should support this. A notable exception is GTK, for which we still use symlinks.

For programs with sufficiently complex configurations, and/or a need to be portable, we separate their configurations into their own flakes. These are done for

- [Neovim](https://github.com/dysthesis/poincare),
- [tmux](https://github.com/dysthesis/daedalus), and
- [the Suckless suite](https://github.com/dysthesis/gungnir).

A notable advantage of this is that it leaves the home directory with almost purely just state. The use of this will be further explored below.

### Impermanence

This is the wiping of root at every reboot, which can be done by either

- placing root on tmpfs, or
- maintaining an 'empty' snapshot (with filesystems such as ZFS or BtrFS), and rolling back to it.

This results in our machines being stateless by default. To maintain state, we would

- maintain a persistence directory, _e.g._ `/nix/persist`),
- place it on an actual volume, and
- bind-mount paths for which we want to maintain state to it.

#### Reverse-impermanence

Unfortunately, [bind mounts incurs a non-trivial performance overhead](https://github.com/nix-community/impermanence/issues/248). This renders read and write speeds much slower.

Since this flake handles mostly desktop configurations, I would imagine this to be more an issue in the home directories, where the user would spend most of their time.

Fortunately, [as mentioned above](#wrappers-as-configuration) the use of wrappers as configuration renders the home directory to be comprised of almost entirely just state. As a result, we can simply place the entirety of `~` on its own drive, instead of a volatile tmpfs.

To eliminate unwanted state, we could instead mount tmpfs there. Some examples of paths we would want to do this for includes

- `~/.cache`,
- `~/.local`, and
- `~/.icons`.

We would therefore be able to minimise the performance overhead experienced in actual day-to-day use.
