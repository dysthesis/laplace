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
