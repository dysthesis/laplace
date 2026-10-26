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

# Obsidian LiveSync on Mimir

The `livesync` cluster instance initially hosts native CouchDB 3 on Mimir at
`https://livesync.dysthesis.com`, behind tailnet-only Caddy. Its recipe owns the
backend, private DNS contribution, credentials, CORS and single-node configuration.
Change `cluster/personal-services.nix`, build all targets (`just deploy build`),
then converge the application, DNS and policy nodes using the
[cluster deployment procedure](docs/cluster.md). No public A record, container,
or upstream `couchdb-init.sh` is needed; that script would replace the loopback
binding with `0.0.0.0`. Syncthing remains an independent instance.

The administrator is `admin`. Retrieve its generated password locally with:

```sh
sops decrypt --extract '["couchdb_admin_password"]' system/secrets/mimir.yaml
```

On the first device, use LiveSync's
[manual CouchDB onboarding](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/quick_setup.md#configure-couchdb-manually-on-the-first-device):
enter the HTTPS URL, credentials, and a separate lowercase database name for each
vault (e.g. `obsidian`). Onboarding creates the database. Enable vault end-to-end
encryption and keep its passphrase separately; use a Setup URI from this device
for subsequent devices. Clients must be on the tailnet. Back up the vault first,
and do not run Syncthing or another synchroniser against the same vault.

`/var/lib/couchdb` is persisted through mnemosyne, including databases, indexes,
the node UUID, and Erlang cookie. This is persistence, not a backup.
Disabling LiveSync removes its active mount declaration, not its backing data.
Moving its host does not move databases, node identity or the Erlang cookie.
The explicit `mimir.yaml` credential source does not follow the hostname; prepare
recipient access and a consistent restore before relocation.

`couchdb_admin_ini` contains a pre-hashed administrator password, installed by
SOPS as a CouchDB-readable runtime file. The plaintext password is not installed
on Mimir or included in the Nix store. Pre-hashing avoids CouchDB writing an
administrator hash into `local.ini` that would override future SOPS rotations.
Manage administrator credentials through SOPS, not Fauxton's mutable settings.

To rotate, edit `couchdb_admin_password` with `sops system/secrets/mimir.yaml`,
then regenerate its paired INI before deploying Mimir:

```sh
python3 - <<'PY'
import hashlib, json, secrets, subprocess
file = "system/secrets/mimir.yaml"
password = json.loads(subprocess.check_output(
    ["sops", "decrypt", "--output-type", "json", file]))["couchdb_admin_password"]
salt = secrets.token_hex(16)
key = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 600000).hex()
ini = f"[admins]\nadmin = -pbkdf2:sha256-{key},{salt},600000\n"
subprocess.run(
    ["sops", "set", "--value-stdin", file, '["couchdb_admin_ini"]'],
    input=json.dumps(ini).encode(), check=True)
PY
```

Changing the INI restarts CouchDB; update every client's password afterwards.
