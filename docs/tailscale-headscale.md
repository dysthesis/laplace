# Tailscale and Headscale

Headscale is a cluster application, initially on Bifrost, with its public Caddy
frontend on Portunus. Bifrost, Portunus, Hephaestus and Talos intentionally remain
outside the Tailnet; the refactor does not bridge those VLAN boundaries.
Headplane is dormant. There is no deployed `headplane.dysthesis.com` UI.

## Configuration authority

- `cluster/machines.nix`: managed host identities, separate unmanaged peers,
  Headscale guest usernames, and explicitly retained static records.
- `cluster/access.nix`: service endpoint references plus genuine node flows.
- `system/services/<name>/cluster.nix`: actual listeners/frontends, DNS ownership
  and placement constraints.
- `cluster/network.nix`: validated concrete connections, dual-stack aliases and
  DNS records; `system/tailnet/` renders Headscale and per-node nftables.

An application domain follows its selected frontend, which can differ from its
backend. Existing DNS records remain A-only. `topos.dysthesis.com` is an explicit
unowned record, not an AFFiNE deployment; NocoDB retains DNS without a proxy.

Service grants use exactly one source selector (`role`, `guest`, `node`,
`service`, or `knownNodes`) and a destination `{service; endpoint;}`. Misspelled
references fail even for absent/disabled applications. Known disabled targets
emit no service grant. A source service resolves to its whole host, not a process.
Node tags remain identity/trust facts and are not service placement selectors.

## Enforcement boundaries

Headscale group memberships retain union semantics. Guest addresses are dynamic:
Headscale authenticates users and nftables gates the corresponding ports for the
Tailnet ranges. Known-node sources expand to known tags rather than `*`, so they
do not include untagged guests. Every address alias has explicit IPv4 `/32` and
IPv6 `/128` forms; Headscale does not infer the other family.

The Headscale renderer still drops protocol, so keep the TCP/UDP-specific host
firewall. Tailnet servers remove `tailscale0` from trusted interfaces; LAN SSH,
fail2ban and scoped non-Tailnet backend ingress remain independent. Exit access
uses `autogroup:internet` and FORWARD, never all-ports INPUT on Charon.

Shared IP:443 grants reach all colocated HTTPS vhosts at the network layer.
Syncthing's unauthenticated GUI therefore retains its explicit proxy source gate.
Existing broad phone grants remain machine-bound, including the retired `device`
identity; neither a service toggle nor a placement edit revokes that access.
Game placement cannot inherit trusted node tags or collocate with trusted apps.

The file policy retains an explicit `acls` array even with zero application
rules. Missing policy or `{}` is allow-all in the pinned Headscale implementation.

## Reconciliation and lifecycle

`just tailnet-reconcile` derives the active Headscale LAN deployment target and
compares names, IPv4/IPv6 addresses and tags. An explicit SSH target can still be
passed. Drift is emitted as structured records; the command reports but never
repairs live enrollment or removes labels.

Headscale owns WG-only peer reconciliation, but these peers bypass normal ACLs
and use explicit stored connections. Omitted peers are not automatically deleted;
disabling Headscale/reconciliation is not revocation or database cleanup.

For disable, full-fleet build/deployment, secret preparation and state transfer,
use the [cluster operator guide](cluster.md). No live membership, external DNS,
OPNsense rule or production service is changed by evaluation alone.
