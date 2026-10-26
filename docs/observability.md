# Argus observability runbook

`argus` starts on VLAN 20 at `10.0.20.84`. VLAN 30 remains a narrow Proxmox
management path: placing every telemetry writer there would widen that trust
boundary and require new Internet egress. A dedicated telemetry VLAN remains a
later option if VLAN 20 becomes too broad.

Current code implements the central stores, Grafana provisioning, two `vmalert`
evaluators, Alertmanager, Blackbox Exporter, bounded host telemetry, persistent
journals, the Argus host, and tailnet policy. Beszel remains unchanged.

Authenticated cross-VLAN HTTPS ingestion is live for all ten remote writers.
Argus writes over loopback. OPNsense TLS syslog remains disabled. Private ntfy
notifications and the Uptime Kuma dead-man receiver are live, although both
notification guests still share one hypervisor. The tailnet-only Grafana
frontend and public certificate are live.

Placement and receiver-owned configuration now come from the `observability`
instance in `cluster/infrastructure-services.nix`; its recipe owns ingestion,
Grafana, alert sinks and optional Minecraft monitoring. Node telemetry participation
is explicit in `cluster/machines.nix`; writer roles/certificates remain attached to
their machines. Apollo remains excluded. The historical live observations below
are not evidence of a deployment of this structural refactor.

The receiver requires declared, separately provisioned observability volumes.
Changing its host does not attach disks or transfer data. It also requires enabled
ntfy and Uptime Kuma; disabling either is an explicit dependency error. Read the
[cluster rollout and relocation procedure](cluster.md) before changing placement.

## Provisioning order

1. Build and restore the 32 GiB root VMA with `just proxmox argus`.
2. Set the restored VM's VLAN/network policy and confirm `10.0.20.84` is unused.
3. Create and attach one 128 GiB virtio disk in PVE with `backup=0`, discard, and
   I/O thread enabled. Record the VM ID and exact PVE command in the ops log.
4. Before starting the databases, partition the new empty disk into a 32 GiB
   metrics partition and a logs partition using the remainder. Format ext4 with
   labels `argus-metrics` and `argus-logs`.
5. Run `findmnt --mountpoint /var/lib/private/victoriametrics` and
   `findmnt --mountpoint /var/lib/private/victorialogs`; confirm their `SOURCE`
   values are distinct. Missing mounts intentionally prevent both databases from
   starting; they must never fall back to the root disk.
6. Generate Argus's persisted age key with `just age-key root@10.0.20.84`, add its
   public recipient and creation rule to `.sops.yaml`, then create
   `system/secrets/argus.yaml`.
7. Enrol Argus in Headscale with `tag:observability` and `tag:infra`; reconcile
   policy with `just tailnet-reconcile`.

Do not repartition by device name until `lsblk --fs` proves which unused disk is
the telemetry disk. The repository deliberately does not automate this
destructive, one-time operation.

## Access

Grafana binds only `127.0.0.1:3000`; backends bind loopback too. Caddy serves
Grafana at <https://observe.dysthesis.com> to the workstation and phone tailnet
roles. Use an SSH tunnel as a recovery path:

```sh
ssh -L 3000:127.0.0.1:3000 root@10.0.20.84
```

Grafana generates a random bootstrap password and secret key under its persisted
state. Read the password once as root:

```sh
sudo cat /var/lib/grafana/bootstrap-admin-password
```

`grafana-sqlite-backup.timer` uses SQLite's online backup API daily and atomically
updates `/var/backups/grafana/grafana.db`, which is on the PBS-backed root persist
volume. Alertmanager state is persisted but remains operationally disposable.

Frontend credentials are SOPS-backed. Do not replace an active Grafana secret
key without following Grafana's key-rotation procedure.

## Dashboards

Grafana provisions the fleet/journal/receiver dashboards and, while the Minecraft
instance is active, its separate game dashboard. Sources live in
`system/services/observability/dashboards`; the generated files parameterize the
active receiver and game placements without relabeling historical host metrics.

- **Fleet overview** is the default home dashboard. Its host selector drives
  node health, CPU, RAM, swap, load, PSI, persistent-root storage, disk/network
  throughput, and recent journal panels. Persistent storage uses
  `mountpoint="/nix/persist"`; `/` is tmpfs on these hosts.
- **Journals** filters VictoriaLogs by host and a raw LogsQL filter. It shows
  volume, severity, latest matching log age, and up to 500 recent entries.
- **Argus self-monitoring** covers central scrapes, Grafana probing, alert state,
  store free space, ingestion, queues, errors, and drops.
- **Minecraft - Retirement Home** combines FabricExporter and Spark game data,
  JVM/GC data, the selected game host's pressure/storage, maintenance timers,
  player events and journal. Its node-local vmagent scrapes the exporter every
  15 seconds; port 25585 remains unexposed. Disabling Minecraft removes its
  scrape contribution, rule group and provisioned dashboard.

`nix build .#checks.x86_64-linux.observability-dashboards` validates dashboard
identity, datasource references, PromQL, and aggregate LogsQL before deployment.

## Notification host

`horos` is the dedicated Uptime Kuma and ntfy guest on VLAN 20 at
`10.0.20.85`. Both applications bind loopback behind tailnet-only Caddy names:
<https://uptime.dysthesis.com> and <https://ntfy.dysthesis.com>. ntfy denies
anonymous access; Alertmanager publishes to `alerts` with a scoped write-only
account. Uptime Kuma and ntfy state use the persisted root; include that disk in
the PBS backup job before production use.

Provision it in this order:

1. Build and restore the image with `just proxmox horos`, then confirm
   `10.0.20.85` is unused before starting the guest.
2. Generate its persisted age key with `just age-key root@10.0.20.85`. Add the
   recipient and a `system/secrets/horos.yaml` creation rule to `.sops.yaml`,
   run `sops updatekeys system/secrets/horos.yaml`, then `just deploy-one horos`.
3. Enrol it in Headscale with `tag:notifications` and `tag:infra`. The policy
   expects `100.64.0.35` and `fd7a:115c:a1e0::23`; update the SSOT first if
   Headscale assigns anything else, deploy Bifrost, then run
   `just tailnet-reconcile`.
4. Read the ntfy administrator password with
   `sops --decrypt --extract '["ntfy_admin_password"]' system/secrets/horos.yaml`,
   log in, and subscribe the phone to `alerts`.
5. Complete Uptime Kuma's first-run administrator setup. Create a push monitor
   for `TelemetryPipelineDeadMan` with a 180-second Heartbeat Interval;
   Alertmanager sends every minute. Configure its ntfy notification against the
   `alerts` topic.
6. Store the generated push URL in `system/secrets/argus.yaml`; Alertmanager's
   `dead-man` receiver reads it through SOPS. Deploy Argus, then test firing,
   resolution, inhibition, and heartbeat expiry.

Horos and Argus share `erebus`. This catches an Argus guest or service failure,
but cannot detect loss of the hypervisor, OPNsense, site power, or site Internet.
The production dead-man exit gate still needs a receiver outside that failure
domain.

## Notification validation

`observability-notification-test.service` is an active oneshot sentinel with no
resident process. Stop it to test the complete warning path, then start it to
resolve the alert:

```sh
systemctl stop observability-notification-test.service
curl --fail http://127.0.0.1:9093/api/v2/alerts
systemctl start observability-notification-test.service
```

Allow about 150 seconds for firing. Resolved delivery may wait for the inherited
five-minute Alertmanager group interval. Always leave the sentinel active.

The 2026-07-13 live test confirmed warning and critical priority, firing and
resolved ntfy delivery, and `TelemetryHostStale` inhibition of the sentinel's
warning for the same host. Stopping `vmalert-metrics` made Uptime Kuma report two
pending retries and then heartbeat failure; restarting it restored the heartbeat
and delivered recovery. Alertmanager recorded no new webhook failures. This does
not satisfy the external dead-man gate while Horos shares Argus's hypervisor.

## Writer rollout

Do not point another host at Argus's raw loopback backends. Argus serves metrics
at `telemetry.dysthesis.com:8443` and journals at port 8444, separate from UI
port 443. Talos has one pinned mTLS credential and fixed metric/log paths. Its
routes overwrite `host` or `source`, reject query methods and paths, enforce
bounded requests/series/queues, and require its source address through Caddy and
nftables.

Remote defaults come from `lib.laplace.telemetry`: `telemetry.writer` defaults
to `networking.hostName` and selects `/<writer>/metrics` and
`/<writer>/journald`; it can differ without changing vmagent's `host` label
or journal-upload's `source` header, which still use the machine hostname.
`metrics.origin` and `journal.origin` independently select an HTTP(S) scheme
and authority (no trailing slash, path, query, or fragment); the matching
Argus ingress domain/port defaults use the same contract but can be configured
separately. `metrics.remoteWriteUrl` and `journal.url` remain explicit,
higher-precedence full-URL overrides, including Argus's loopback URLs; they
are not normalized. When a stream is enabled, explicitly setting its URL to
`null` remains invalid.

The origin guard only protects URL joining; it is not complete hostname,
IPv6, or port validation. The sending binaries and backends still handle the
actual destination, including arbitrary full-URL overrides. An enabled
stream's TLS client certificate still requires an HTTPS URL; credential
pairs remain required even when that stream is disabled, without forcing its
unused origin or URL through the HTTPS assertion.

By default, `journal.url` is the slash-free _base_ `/<writer>/journald`. The
pinned systemd-journal-upload 260.4 appends `/upload`, sending
`POST /<writer>/journald/upload`, which Argus accepts; an isolated
disposable-journal request confirmed this boundary. Full-URL overrides must
account for this suffix. Sender routing, receiver writer admission,
and the separate `observability.expectedHosts` monitoring acknowledgement
are independently authored: changing an origin or writer identity alone does
not update accepted clients or monitored hosts. Coordinate rollout without
assuming an atomic cutover or automatic enrollment.

Another disposable-journal capture used an evaluated `writer=canary` and
loopback-only journal origin; the actual pinned 260.4 uploader sent
`POST /canary/journald/upload` without a `Content-Encoding` header. Neither
capture exercised live mTLS, the Caddy receiver, or staged writer migration.

Node consumers now derive `telemetry.dysthesis.com` LAN pins and ingestion origins
from the selected receiver endpoint. There is no independently maintained address
table in the host files. Writer names, source addresses, certificates/fingerprints
and monitoring membership remain machine-bound. Receiver relocation needs an
explicit remote credential/admission for the old receiver; the initial Argus
loopback writer has no remote client key to move automatically.
During a writer-identity rename, retaining the old admission also retains its
`expectedHosts` monitoring obligation, while removing the old route before
old clients switch rejects their writes. Plan the transition explicitly.

Live tests rejected missing and unknown certificates, wrong source, method,
path, admin/query access, compressed journals, oversized writes, forged identity,
and a ninth concurrent connection. Talos is now the first remote canary and is in
`observability.expectedHosts`. Its journal and upload cursor are persisted at
`/var/log/journal` and `/var/lib/private/systemd/journal-upload`; vmagent's queue
is persisted under `/var/cache/private/vmagent`.

Complete backend-outage, reboot, queue-drain, and cursor-survival tests before
rolling out VLAN 20 and isolated guests. Give every new writer its own route
identity, distinct mTLS leaf, fingerprint, source rule, and central vmagent
port; explicitly add its ingress writer and expected-host entry in the same
change. The expected-host equality and duplicate checks retain separate
monitoring acknowledgement. Keep Beszel until equivalent alerts have run for
one month.

The 2026-07-13 Argus reboot test started with VictoriaLogs stopped. System
startup finished in 13.359 seconds with both telemetry filesystems remounted
from `/dev/vdb1` and `/dev/vdb2`. Journal upload retried once while VictoriaLogs
started, then its persistent cursor advanced. Unique pre- and post-reboot
journal canaries each remained exactly once locally and centrally after a
further 75 seconds. All telemetry services recovered, node metrics were 0.85
seconds fresh, Grafana was healthy, and no systemd units remained failed.

Filesystem warning rules cover 6.5-7 GiB free for VictoriaMetrics and 18-20 GiB
free for VictoriaLogs. Critical rules start below those bands, before the
backends' respective 6 GiB and 16 GiB minimum-free write stops. The
`observability-rules` flake check uses `vmalert-tool` with isolated synthetic
series to verify both stores, severities, annotations, and lack of overlap. A
live test must still use disposable storage; never fill either production
telemetry filesystem to exercise these rules.

The 2026-07-13 Talos path test temporarily blocked only TCP 8443 and 8444 to
Argus, with an automatic ten-minute nftables rollback. `TelemetryHostStale` and
then `TelemetryHostAbsent` each fired with `host=talos`. The test firewall
dropped 1,199 packets; vmagent's bounded queue peaked at 263,592 bytes and
drained within 45 seconds after recovery, with zero dropped packets. Unique
pre-, during-, and post-block journal canaries each arrived exactly once. Talos
metrics recovered to 9.3 seconds fresh, both hosts had no failed units, and the
test firewall was removed.

The live stale alert disappeared when its instant selector crossed the default
five-minute query lookback, leaving a gap while the absent alert was pending.
The deployed rule now reads the last ten minutes explicitly, and the isolated
rule test requires stale and absent alerts to overlap at 6 minutes 30 seconds.
The live vmalert API was checked against that expression on 2026-07-14.

## Appliance work

PVE, PBS, and OPNsense remain external configuration:

- send PVE/PBS Influx metrics only to the authenticated metric-write route;
- configure OPNsense Telegraf without source/destination IP or port tags;
- enable `opnsenseSyslog` only after its TLS cert/key exist in SOPS and OPNsense's
  source address is confirmed;
- begin with system, firewall action, DHCP, Unbound, gateway, and VPN logs;
- use Blackbox DNS probes for AdGuard before considering an API exporter.

## Validation

Run these before remote rollout:

```sh
systemctl status victoriametrics victorialogs grafana alertmanager
systemctl status vmalert-metrics vmalert-logs vmagent systemd-journal-upload
curl --fail http://127.0.0.1:8428/health
curl --fail http://127.0.0.1:9428/health
curl --fail http://127.0.0.1:3000/api/health
findmnt --mountpoint /var/lib/private/victoriametrics
findmnt --mountpoint /var/lib/private/victorialogs
journalctl --unit systemd-journal-upload --since=-10m
```

Periodic failure checks must stop each backend, reboot during an outage, fill
disposable filesystems, inject malformed and high-cardinality input through the
authenticated proxy, block one writer VLAN, test external dead-man delivery, and
restore the root disk with empty telemetry storage. Base retention and disk-limit
changes on at least 14 days of growth, resource, and query measurements.
