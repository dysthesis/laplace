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

`hosts/desktops.nix` selects ordinary values before the NixOS module imports are
assembled. NixOS and Colmena receive the same `desktopSelection` special argument;
package construction still uses the host's existing package set. Presets live in
`system/display/presets.nix`. Deimos and Phobos use `presets.integrated`.

For example, to retain Noctalia and Vicinae but replace the primary bar on Phobos:

```nix
let
  presets = import ../system/display/presets.nix;
in {
  deimos = presets.integrated;
  phobos = presets.integrated // {bar = ../user/wrapped/waybar;};
}
```

This disables Noctalia's actual bar and starts configured Waybar through Niri's
existing session target. Noctalia retains notifications, wallpaper, idle policy
and shell controls; appearance and authentication policy remain integrated.
There is no independent notification selector.

Supported managed compositions:

- `presets.integrated`: Niri, Noctalia, Vicinae and Foot.
- `presets.standalone`: Niri, Foot, Fuzzel, Waybar, Dunst and swaybg.
- Integrated Niri with the explicit Waybar replacement above.
- `presets.legacy (import ../system/display/servers/wayland/compositors/sway)`
  preserves the existing custom Sway path. The same constructor accepts the
  existing Hyprland, River and dwl providers, or
  `../system/display/servers/xorg/sessions/xmonad`. These keep their own startup
  mechanisms; they do not acquire native Sway integration or new component mixes.

Only the existing Foot operation adapter is supported. Terminal operations reach
Niri bindings, matching, swallowing, Fuzzel and the note helpers. Legacy compositor
bindings retain their fixed defaults; unsupported terminal, launcher, shell and
bar combinations fail assertions rather than being accepted and ignored.
Integrated Niri requires Vicinae's application and clipboard-history operations;
Fuzzel is not a replacement for that complete contract. Independent configured
Foot uses and WezTerm `imgcat` remain available.

`config.laplace.wm` is a typed, read-only **result**, not a selection option. It is
either null or `{ protocol; login; logout; }`, with `logout = null` where no
external control operation is consumed. Operations are non-empty argument
vectors with an absolute executable, not shell command strings. Bash uses the
complete login vector under the existing desktop-profile, empty-`DISPLAY`, VT1
guard. It adds no compositor flags. Niri supplies configured `niri-session` for
the login context; native Niri integration owns environment import, waiting and
shutdown. Noctalia receives raw Niri logout IPC separately to avoid a configured
Niri/Noctalia dependency cycle.

`presets.none`, an absent host entry, or a preset with `wm = null` imports no
managed provider and starts no managed session-bound components. Shared desktop
profile services and GTK portals remain; Chaos's upstream GNOME installer is an
external desktop, not a headless host. Null selection does not remove home data,
independent packages or previous generations. The old display/session selectors
and global configured Niri/Noctalia exports have been removed.

Build before activation:

```sh
nix build --no-link --no-write-lock-file \
  .#checks.x86_64-linux.desktop-stack \
  .#checks.x86_64-linux.niri-config \
  .#checks.x86_64-linux.mk-wrapper
nix build --no-link --no-write-lock-file \
  .#nixosConfigurations.deimos.config.system.build.toplevel \
  .#nixosConfigurations.phobos.config.system.build.toplevel
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

Checks cover actual selected configuration validation, provider removal,
standalone/external-bar service ownership and operation boundaries. Evaluation
and parser success do not establish VT1 login, logout/re-login cleanup, lock and
authentication prompts, portal behaviour or Noctalia panel usability without its
bar. Verify these on an authorised desktop rollout with saved work, a recovery
console and the previous bootable generation retained. A generation switch is
not an atomic live desktop replacement; use logout/login or reboot and roll back
if those checks fail.

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
