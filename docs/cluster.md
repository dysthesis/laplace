# Service-first cluster configuration

`cluster/inventory.nix` imports the site declarations. Change application placement
and enablement there, not in `hosts/<machine>` or a NixOS wrapper:

```nix
laplace.services.miniflux = {
  host = "mimir";
  settings = {
    domain = "miniflux.dysthesis.com";
    sopsFile = ../system/secrets/mimir.yaml;
    listenAddress = "0.0.0.0";
    allowPrivateNetworks = true;
    useKarakeepBrowser = true;
  };
};
```

A declared instance defaults to enabled. An absent entry is `null` and deploys
nothing. Set `enable = false` to retain its typed declaration without projecting
its application. Disabled declarations still validate required host/settings,
unknown names and placement constraints. Overrides that only set `enable = false`
work when the base declaration supplies the required fields.

## Ownership

| Authority                                                              | Owns                                                                                                                                                                                           |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cluster/machines.nix`                                                 | Managed host class, platform, LAN/deployment address, trust/storage capabilities, explicit Tailnet identity, node telemetry/Beszel participation; separate external peers and guest membership |
| `cluster/personal-services.nix`, `cluster/infrastructure-services.nix` | All 20 deployed singleton declarations and their typed site settings                                                                                                                           |
| `cluster/access.nix`                                                   | Service endpoint grants and intentional whole-node/exit flows                                                                                                                                  |
| `system/services/<name>/cluster.nix`                                   | Settings schema, endpoint/resource metadata, dependencies and complete per-host/cross-host contribution                                                                                        |
| `hosts/<machine>`                                                      | Interfaces/VLANs/gateways, hardware/disks/VM sizing, secret identities for node writers, local resolver choices, shared Caddy/TLS facilities and network roles                                 |
| `system/services/<name>`                                               | Reusable NixOS implementation; not a second production placement authority                                                                                                                     |

The catalogue includes Miniflux, NocoDB, Altero, SilverBullet, Vikunja, Radicale,
Karakeep, Beszel hub, Syncthing server, LiveSync, Immich, Minecraft, the music
pipeline, observability, Uptime Kuma, ntfy, AdGuard Home, Forgejo, Forgejo runner,
and Headscale. Syncthing/LiveSync and Kuma/ntfy are independent instances. Music
is the existing localhost-coupled media pipeline, not independently movable apps.

Dormant AFFiNE, Cloudflared, Headplane, LLM, Radicle, SearxNG and Taskchampion
implementations are not activated or registered by scanning directories. Deimos's
offline Minecraft pre-generation fragments remain dormant, not a server-role
exception. NocoDB keeps its DNS-only exposure; no proxy was added. `topos` remains
an explicitly unowned static DNS record. Apollo still sends no telemetry.

## Validation and inspection

```sh
nix eval --json .#laplace
nix eval --json .#laplace.activeServices
nix eval --json .#laplace.network
nix build .#checks.x86_64-linux.cluster-contracts \
  .#checks.x86_64-linux.cluster-global-validation \
  .#checks.x86_64-linux.cluster-evaluator-parity \
  .#checks.x86_64-linux.cluster-personal-services
nix build .#checks.x86_64-linux.cluster-lifecycle
```

The finite manifest contains declarations, active placements, endpoints, resource
reservations and resolved connections. No packages, executable recipes, runtime
SOPS placeholders or decrypted values are exported. Both host constructors force
this model before exposing a node; Colmena receives each node's shared
`specialArgs`, modules, architecture and overlays. NixOS system assertions still
need checked evaluation/build; a leaf option is not proof of a valid system.

Encrypted source paths are copied into context-carrying store strings before the
finite model is forced. Derivation-backed sources retain their output dependency
without traversing package metadata. A printed pathname alone is not proof that
SOPS can read the source in a build sandbox.

The lifecycle check boots three disposable VMs with real Miniflux, PostgreSQL,
Caddy, Syncthing and Mnemosyne. It checks dual-stack direct access and shared-HTTPS
authorization, switches to a disabled generation, verifies unrelated service
continuity and retained backing data, then re-enables and reads the same API
record. It does not exercise live Tailscale enrollment or production convergence.

Only managed deployable servers are application targets. Workstations, the ISO,
external peers, unknown names and servers without a deployment target fail.
Trust and declared storage constraints additionally protect game/CI/git/control
plane/edge boundaries. Minecraft requires isolated game identity and Btrfs;
observability requires its separately provisioned volumes. Capacity declarations
are not evidence of live free space or usable backups.
Targets must also declare the shared Caddy facility; AdGuard requires its DNS
listener reservation rather than colliding with systemd-resolved or Unbound.
Those facts assert configured prerequisites, not capacity discovered from a live
host. Provision the machine facility before admitting a new compatible target.

Listener overlaps, duplicate domains, exclusive/nested state paths, fixed UIDs
(including NocoDB's host-side UID 999), database names/users and incompatible
PostgreSQL versions are rejected. Listener comparison removes IPv6 brackets and
normalises hexadecimal case, compression and leading zeroes, retaining scope
identifiers; equivalent spellings cannot claim separate sockets. Caddy listeners
and PostgreSQL provider state are explicitly shared. Metadata is a finite recipe
contract, not a scheduler or a live process/port inventory.

Hard consumers fail rather than silently changing another service: Miniflux's
configured browser requires colocated Karakeep; the runner requires Forgejo;
Headscale resolver advertisement requires AdGuard; observability requires ntfy
and Kuma; declared Beszel/telemetry nodes require their providers. Removing a
provider therefore requires an explicit consumer decision. An observability move
also needs remote-writer identities for the former receiver; writer names,
certificates/fingerprints, source addresses and host labels do not move with it.
Optional Minecraft monitoring disappears when Minecraft is disabled.

The music recipe reconciles qBittorrent's owned host allowlist before startup when
its domain changes; generated credentials and other mutable profile settings stay
untouched.

## Network semantics

Endpoint references select addresses and ports, not new security identities.
Service aliases include both `/32` IPv4 and `/128` IPv6 addresses. DNS publishes
only the existing A records, from the frontend machine; no AAAA/public-DNS
updates are implied. Forgejo and Headscale retain separate Portunus frontends,
scoped LAN backend ingress, Forgejo's Anubis/client headers and SSE handling.
Their backend `listenAddress` must be `0.0.0.0` or the backend host's declared
LAN address. Loopback, IPv6-only and unrelated-address binds are rejected because
the frontends and Forgejo runner dial the advertised IPv4 LAN endpoint.

Headscale authorizes guest username groups; nftables admits their dynamic Tailnet
address ranges only on allowed ports. Overlapping group memberships remain a
union. Known-node selectors expand to known tags, never a global guest wildcard.
Headscale still omits protocol, so the protocol-specific nftables gate is required.
Exit grants remain forwarding, not all-ports INPUT access.

A service-source grant authorizes its whole machine, not its process. Shared
IP:443 does **not** isolate HTTP vhosts. Syncthing keeps its proxy-level owner
source gate: `guiClients` is enforced by Caddy, so the GUI must bind to
`127.0.0.1`, `localhost`, `::1` or `[::1]`; other binds fail validation. Existing
phone whole-node grants stay attached to nodes and can still permit a disabled
service's former port; disabling removes only that service's contribution.
Live tags are not silently retagged or revoked. The
Headscale file always contains an explicit `acls` array, even when empty; an
absent policy or `{}` would allow all at the pinned Headscale version.

`just tailnet-reconcile` derives the control-plane deployment address and checks
live node names/tags/addresses against the manifest. Its structured JSON drift
report does not repair enrollment. WG-only peers remain outside ordinary ACLs;
the reconciler does not delete omitted peers, and disabling it is not revocation.

## Build, then converge

```sh
# Mandatory all-target preflight for this cutover and every stateful move.
just deploy build
# Activate only after the build succeeds and an explicit rollout order is chosen.
just deploy switch
# Existing authenticated LAN-copy workaround remains available.
just deploy-one mimir switch
```

`just deploy` selects `@server` and forwards the original goal/flags unchanged.
Every deployable server stays selected even with zero applications. `deploy-one`
keeps its build, authenticated LAN copy and bounded activation behavior. Ordinary
Colmena apply is not a fleet transaction: chunked evaluation and parallel
activation can leave successful siblings active after another node fails.
`--parallel 1` alone is not dependency ordering. Keep independent LAN SSH working,
use canaries and explicit policy/DNS/edge/control-plane order, then verify every
affected node converged. No production activation is performed by this refactor.

## Disable and decommission

After a valid `enable = false` and successful fleet convergence, the service's
units/containers/timers, routes, DNS, endpoint grants, optional monitoring and
service-only secret consumers disappear. Shared engines, unrelated apps,
node-level policy and node identities remain. Disabling a provider with an active
hard consumer fails before deployment. Removing the declaration has the same
desired absence but retains no settings.

**Disabling is not deleting data. Moving is not copying data.** Mnemosyne can
remove an active bind mount while `/nix/persist` backing data and backups remain.
No cleanup infers deletion from an absent service. Secret consumer removal is not
credential revocation: old generations, ciphertext and disclosed plaintext may
remain accessible. Security decommissioning may require authorized rotation.

Do not remove a host or its server/deployment role first. Decommission its apps
while it is still deployable, converge and verify absence, then remove the host.
An unknown machine cannot receive a desired stop configuration.

## Stateful relocation

1. Verify trust/network/storage compatibility, actual capacity, fresh usable
   backups and an application-specific restore procedure.
2. Prepare storage and decryption rights without starting another writer.
   Keep explicit encrypted source/key references; a new hostname does not imply
   `secrets/<new-host>.yaml` contains or can decrypt the old credentials.
   Update recipients on the real ciphertext with `sops updatekeys`; editing
   `.sops.yaml` alone does not update them. A host-scoped file discloses all its
   contents, so split ciphertext before moving across credential boundaries.
3. Build old/new host, edge, DNS/policy and consumer closures before activation.
4. Resolve hard consumers, quiesce and stop the old writer, verify it stopped.
   Prefer convergence of a disabled instance before transfer when its dependency
   and retained mount requirements permit that sequence.
5. Transfer only the application dataset using consistent backup/restore and
   preserved owners/identities. Never copy an entire shared PostgreSQL cluster
   merely to move one database. Preserve DynamicUser private paths, UID/GIDs,
   CouchDB/Erlang and Syncthing identities, runner registration, Grafana material,
   Headscale keys/database/WG-only state, and Minecraft snapshot assumptions.
6. Enable on the target and activate frontends/policies in a service-specific
   order. Smoke authorized and denied client paths, DNS, metrics and notifications.
7. Verify old-host absence and all consumers; retain rollback data through an
   observation period.
8. After new writes/schema changes, rollback requires state reconciliation or
   restore. Redeploying an old Nix generation does not undo data changes.
