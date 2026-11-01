import configparser
from contextlib import closing
import json
import os
from pathlib import Path
import secrets
import signal
import sqlite3
import subprocess
import tempfile
import time

os.umask(0o077)
state = Path(os.environ["GRAFANA_STATE_DIR"])
database = Path(os.environ["GRAFANA_DATABASE_PATH"])
staged = state / "dashboards"
staged.mkdir(mode=0o750, parents=True, exist_ok=True)
# Initialise bootstrap secrets only when absent or empty.
for name, size in [("secret-key", 32), ("bootstrap-admin-password", 24)]:
    path = state / name
    if not path.exists() or path.stat().st_size == 0:
        path.write_text(secrets.token_hex(size) + "\n")

sources = {
    json.loads(source.read_text())["uid"]: source
    for source in Path(os.environ["GRAFANA_DASHBOARD_SOURCES"]).glob("*.json")
}

def dashboard_paths(path):
    if not path.exists():
        return {}
    with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True, timeout=2)) as db:
        db.execute("BEGIN")
        tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
        # The two dashboard schemas can contain rows.
        # Use the Grafana migration log to select the active schema.
        unified = "unifiedstorage_migration_log" in tables and db.execute(
            "SELECT 1 FROM unifiedstorage_migration_log "
            "WHERE migration_id = ? AND success = 1 LIMIT 1",
            ("folders and dashboards migration",),
        ).fetchone()
        placeholders = ",".join("?" for _ in sources)
        if unified:
            rows = db.execute(
                'SELECT name, value FROM resource WHERE namespace = ? AND "group" = ? '
                f'AND resource = ? AND name IN ({placeholders})',
                ("default", "dashboard.grafana.app", "dashboards", *sources),
            )
            result = {}
            for uid, value in rows:
                annotations = json.loads(value)["metadata"].get("annotations", {})
                if (annotations.get("grafana.app/managedBy") == "classic-file-provisioning"
                        and annotations.get("grafana.app/managerId") == "Laplace"):
                    result[uid] = annotations.get("grafana.app/sourcePath", "")
            return result
        if {"dashboard", "dashboard_provisioning"} <= tables:
            # The provider uses organisation ID 1, named "default" in unified storage.
            # Do not use its display name.
            return dict(db.execute(
                "SELECT d.uid, p.external_id FROM dashboard AS d "
                "JOIN dashboard_provisioning AS p ON p.dashboard_id = d.id "
                f"WHERE d.org_id = 1 AND p.name = ? AND d.uid IN ({placeholders})",
                ("Laplace", *sources),
            ))
        return {}

owned = dashboard_paths(database)
pending = {
    uid: source.name for uid, source in sources.items()
    if owned.get(uid, "").startswith("/nix/store/")
    and Path(owned[uid]).name == source.name
}

def stage_dashboards(uids):
    for uid, source in sources.items():
        target = staged / source.name
        target.unlink(missing_ok=True)
        if uid in uids:
            target.symlink_to(source)

if pending:
    # Reconcile only Laplace-owned dashboards with store paths.
    # Do not start a private Grafana process for other databases.
    stage_dashboards(owned)
    runtime = Path(os.environ["RUNTIME_DIRECTORY"]) / "dashboard-ownership"
    runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    runtime.chmod(0o700)
    stop_requested = False

    def interrupted(signum, frame):
        global stop_requested
        stop_requested = True

    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)

    def copy_database(source, destination):
        with closing(sqlite3.connect(source.as_uri() + "?mode=ro", uri=True)) as source_db:
            with closing(sqlite3.connect(destination)) as destination_db:
                source_db.backup(destination_db)

    log = runtime / "grafana.log"
    with tempfile.TemporaryDirectory(prefix="migration-", dir=runtime) as temporary:
        work = Path(temporary)
        private_database = work / "grafana.db"
        # Native provisioning can remove dashboard ownership before an import.
        # Copy the result only after reconciliation completes and Grafana stops.
        # Failures and interrupts must leave the original ownership unchanged.
        copy_database(database, private_database)
        provisioning = work / "provisioning"
        for directory in ["dashboards", "datasources", "alerting", "plugins"]:
            (provisioning / directory).mkdir(parents=True, exist_ok=True)
        # Grafana deletes dashboards when a file provider disappears from its configuration.
        # Keep other providers registered at an absent path to prevent changes.
        provider_names = set()
        with closing(sqlite3.connect(private_database.as_uri() + "?mode=ro", uri=True)) as db:
            tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
            if "dashboard_provisioning" in tables:
                provider_names.update(row[0] for row in db.execute(
                    "SELECT DISTINCT name FROM dashboard_provisioning"
                ) if row[0])
            if "resource" in tables:
                provider_names.update(row[0] for row in db.execute(
                    'SELECT DISTINCT json_extract(value, ?) FROM resource WHERE "group" = ? '
                    'AND resource = ? AND json_extract(value, ?) = ?',
                    ('$.metadata.annotations."grafana.app/managerId"', "dashboard.grafana.app",
                     "dashboards", '$.metadata.annotations."grafana.app/managedBy"',
                     "classic-file-provisioning"),
                ) if row[0])
        (provisioning / "dashboards" / "laplace.yaml").write_text(json.dumps({
            "apiVersion": 1,
            "providers": [{
                "name": "Laplace",
                "type": "file",
                "disableDeletion": True,
                "updateIntervalSeconds": 30,
                "options": {"path": str(staged)},
            }] + [{
                "name": name,
                "type": "file",
                "disableDeletion": True,
                "options": {"path": str(work / "unwatched")},
            } for name in sorted(provider_names - {"Laplace"})],
        }))
        private_socket = runtime / "grafana.sock"
        private_socket.unlink(missing_ok=True)
        settings = configparser.ConfigParser(interpolation=None)
        settings.read_dict({
            "paths": {
                "data": str(work / "data"),
                "logs": str(work / "logs"),
                "plugins": str(work / "plugins"),
                "provisioning": str(provisioning),
            },
            "database": {"type": "sqlite3", "path": str(private_database)},
            "server": {
                "protocol": "socket",
                "socket": str(private_socket),
                "socket_mode": "0600",
                "root_url": "http://localhost/",
            },
            "security": {
                "disable_initial_admin_creation": "true",
                "secret_key": os.environ["GRAFANA_SECRET_KEY"],
            },
            "analytics": {
                "reporting_enabled": "false",
                "check_for_updates": "false",
                "check_for_plugin_updates": "false",
            },
            "plugins": {
                "preinstall_disabled": "true",
                "public_key_retrieval_disabled": "true",
            },
            "unified_alerting": {"enabled": "false"},
            "log": {"mode": "console", "level": "warn"},
        })
        config = work / "grafana.ini"
        with config.open("w") as output:
            settings.write(output)
        try:
            with log.open("w") as output:
                process = subprocess.Popen(
                    ["@grafanaExecutable@", "server",
                     "-homepath", "@grafanaHome@",
                     "-config", str(config)],
                    stdout=output, stderr=subprocess.STDOUT,
                )
                try:
                    deadline = time.monotonic() + 90
                    while True:
                        if stop_requested:
                            raise RuntimeError("Dashboard reconciliation interrupted")
                        if process.poll() is not None:
                            raise RuntimeError("Private Grafana exited before dashboard reconciliation")
                        paths = dashboard_paths(private_database)
                        pending = {
                            uid: filename for uid, filename in pending.items()
                            if paths.get(uid) not in (filename, str(staged / filename))
                        }
                        if not pending:
                            # The database shows ownership before Grafana releases its provisioning lease.
                            with closing(sqlite3.connect(private_database.as_uri() + "?mode=ro", uri=True)) as db:
                                locked = db.execute(
                                    "SELECT 1 FROM server_lock WHERE operation_uid = ?",
                                    ("provisioning_dashboards",),
                                ).fetchone()
                            if locked is None:
                                break
                        if time.monotonic() >= deadline:
                            raise RuntimeError(f"Dashboard reconciliation timed out: {pending}")
                        time.sleep(0.25)
                finally:
                    if process.poll() is None:
                        process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=10)
                        raise RuntimeError("Private Grafana did not stop within its shutdown deadline")
            if stop_requested:
                raise RuntimeError("Dashboard reconciliation interrupted")
            copy_database(private_database, database)
            if stop_requested:
                raise RuntimeError("Dashboard reconciliation interrupted")
        except BaseException:
            print(log.read_text(), flush=True)
            raise

# Stage only configured files for normal provisioning with deletion enabled.
# Do not recreate a disabled game on restart.
stage_dashboards({
    uid for uid, source in sources.items()
    if source.name != "minecraft.json" or os.environ["GRAFANA_MINECRAFT_ENABLED"] == "1"
})
