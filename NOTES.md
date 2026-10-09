# Building images

NixOS upstreamed `nixos-generators`.

# PyTorch ROCm sandbox builds

`just rebuild` failed during CK SDPA generation because `add_make_kernel_pt.sh`
used `#!/bin/bash`, which is unavailable in the Nix sandbox. The unstable Python
overlay appends `patchShebangs --build` to ROCm-enabled Torch's existing
`postPatch`, before CMake executes the helper. ROCm, CK SDPA and Headroom remain enabled.

A sandbox smoke using Torch's source/preparation and the upstream CK CMake file
completed forward, split-KV, append-KV and backward generation (1,052 `.hip` files).

The next failure was HIP's host header defining `__noinline__` as empty before
GCC 16's `<chrono>` loaded `<format>`, leaving the invalid attribute `[[__gnu__::]]`.
ROCm Torch now preincludes `<chrono>` through host-only `CXXFLAGS` after inherited
`preConfigure`, retaining existing flags and HIP macros without altering C or HIP
device flags. A sandbox smoke compiled both Kineto profiler units and c10's
`HIPDeviceAssertionHost`, `HIPFunctions` and `HIPAllocatorConfig` with GCC 16.2,
ROCm 7.2.3, C++20 and the existing warning/error flags.
Unset `CXXFLAGS` inherits `CFLAGS` as upstream requires; explicitly empty
`CXXFLAGS` does not.

Torch's standard `.override` API is retained. Repairs follow its effective ROCm
flag, including explicit variants, leaving non-ROCm preparation and cache identities unchanged.

# Zotero Gecko compatibility

Zotero 10.0.4 declares Gecko ESR 140 in `app/config.sh`, but unstable nixpkgs
supplies ESR 153. `just rebuild` aborts while modifying
`modules/ActorManagerParent.sys.mjs`; ESR 153 also changed the add-ons page layout.

The unstable overlay overrides only Zotero's Gecko dependency with stable
`firefox-esr-140-unwrapped` (140.17.0esr). Zotero stays at 10.0.4 and remains in
both desktop users' package lists, with its upstream build customizations intact.
The repaired package builds and its `--version` command runs successfully.

ESR 140 is end-of-life according to unstable nixpkgs. This is a compatibility
override, not an ESR 153 port; remove it when Zotero supports the current ESR.
No insecure-package allowance is added.

The complete Deimos configuration also builds successfully with `nh os build`;
system activation is left to `just rebuild`.
