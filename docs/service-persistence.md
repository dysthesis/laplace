# Service state persistence

Each application recipe owns its persistence declarations. With `DynamicUser`
and `StateDirectory=<name>`, persistent state normally lives under
`/var/lib/private/<name>`. Preserve the actual path, owner and mount ordering;
there is no automatic state discovery or purge.

Mnemosyne bind-mounts data from `/nix/persist`. Disabling/removing an instance can
remove an active mount without deleting its backing directory or backups.
Re-enabling on the same host can reuse that data. Changing `host` never transfers
it to another machine and must not start a second writer before restoration.

PostgreSQL state is a shared provider resource, with application-specific database
and user ownership. Do not copy/drop the whole provider to move one application.
Immich retains its original versioned mount unless a colocated Miniflux requires
the shared parent mount. Fixed UIDs, exclusive paths and incompatible listeners
are checked in the finite cluster model; actual capacity and consistent backups
remain operator obligations.

Secrets are also state: preserve CouchDB/Syncthing identities, runner registration,
Grafana encryption material and Headscale database/keys/WG-only state. Consumer
removal does not revoke a credential or remove old Nix generations. Follow the
[cluster relocation procedure](cluster.md), including destination SOPS recipients,
application-specific backup/restore, old-writer shutdown and explicit rollback.
