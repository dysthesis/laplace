Proxmox
=======

Some of the hosts here are Proxmox guests, running on a Proxmox node `erebus` in
my cupboard (NUC13ANKH5, slim "K" chassis, 37mm, i5-13420H, 32 GB RAM, 1 TB M.2
NVMe SSD). As of writing this, we have the following Proxmox hosts:

```nix
nix-repl> isProxmoxHost = (_: host: builtins.elem "proxmox" host.config.laplace.profiles)

nix-repl> proxmoxHosts = (builtins.filterAttrs isProxmoxHost  nixosConfigurations)

nix-repl> lib.mapAttrsToList (k: _: k) proxmoxHosts
[
  "bifrost"
  "charon"
  "hephaestus"
  "hermes"
  "horos"
  "loki"
  "mimir"
  "mneme"
  "portunus"
]
```

Profile
-------

Setting `config.laplace.profiles = ["proxmox"]` enables sane defaults for Proxmox
guest, including QEMU integration and building VMA images to restore from. 

Building VMA images
-------------------

Run `just proxmox <hostname>` to build the VMA image, ready to deploy to Proxmox.
This only works for hosts which has enabled the `proxmox` profile.


Proxmox-only options
--------------------

Some options are exclusive to the Proxmox profile -- they define parameters e.g.
RAM allocation and ballooning, number of cores to allocate, network bridge to
attach, disk size, etc. These are applied once during the restoration of the VMA
image and is then overrideable imperatively from the Proxmox Web UI. Changing
this value in Nix no longer matters post-installation.

tmpfs root
----------

All of the hosts have impermanence enabled. The "root" filesystem is created
as a function of the ballooning _floor_ instead of the ceiling if the former
is available. It is either $\frac{3}{4}$ of the floor, or half of the ceiling.

