# Proxmox

Some of the hosts here are Proxmox guests, running on a Proxmox node `erebus` in
my cupboard (NUC13ANKH5, slim "K" chassis, 37mm, i5-13420H, 32 GB RAM, 1 TB M.2
NVMe SSD). Inspect deployable servers with:

```sh
nix eval --json .#laplace.hosts
```

Deployment uses the inventory's explicit `server` role, not the `proxmox`
profile or the set of active applications. All twelve server targets remain in
`just deploy`'s `@server` selection when an application is disabled.
Cross-host LAN addresses and deployment targets have one authority in
`cluster/machines.nix`; interfaces, gateways and VM/storage provisioning stay
under `hosts/`.

## Profile

Setting `config.laplace.profiles = ["proxmox"]` enables sane defaults for Proxmox
guest, including QEMU integration and building VMA images to restore from.

## Building VMA images

Run `just proxmox <hostname>` to build the VMA image, ready to deploy to Proxmox.
This only works for hosts which has enabled the `proxmox` profile.

For a structural cutover or stateful relocation, run `just deploy build` for
the full server selection before any activation. `just deploy switch` is not
transactional or dependency-ordered; use the
[cluster rollout/relocation procedure](cluster.md). A placement edit neither
restores a VMA nor attaches disks, grants decryption rights, or copies state.

## Hardened-kernel smoke

Before deploying a changed hardened-kernel build, run the on-demand disposable
QEMU check:

```sh
nix build --no-link -L .#packages.x86_64-linux.linux-hardened-boot-test
```

It uses the unchanged overlay kernel, checks its release and `/proc/kcore`
absence, and loads the profile's VirtIO/storage modules plus Btrfs in both the
systemd initrd and multi-user userspace. This is not a production disk-layout,
bootloader, persistence, secret-decryption or full hardening-policy test.

At the pinned systemd 260.5/Nixpkgs versions, initrd assembly warns about
`libcrypt.so.1` and `libcrypt.so.1.1`. These are alternate SONAMEs for password
hashing: systemd successfully loads `libcrypt.so.2` first, but the initrd collector
checks every alternative independently. The built Argus initrd includes
`libcrypt.so.2`. Do not add compatibility libraries or suppress these messages
merely to silence them; recheck actual dependencies after package updates.

## Proxmox-only options

Some options are exclusive to the Proxmox profile -- they define parameters e.g.
RAM allocation and ballooning, number of cores to allocate, network bridge to
attach, disk size, etc. These are applied once during the restoration of the VMA
image and is then overrideable imperatively from the Proxmox Web UI. Changing
this value in Nix no longer matters post-installation.

## tmpfs root

All of the hosts have impermanence enabled. The "root" filesystem is created
as a function of the ballooning _floor_ instead of the ceiling if the former
is available. It is either $\frac{3}{4}$ of the floor, or half of the ceiling.
