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
# Initialise bootstrap material only when missing, as on ordinary startup.
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
        # Grafana 13 keeps legacy rows after moving dashboards to resource.
        # Its own migration log selects the authoritative ownership schema;
        # it is not a Laplace cutover marker and is restored with the DB.
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
            # The provider's historical default is numeric org ID 1,
            # called "default" in unified storage, never its display name.
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
    # Only existing Laplace-owned dashboards take part in adoption.
    # Fresh and already-stable databases need no extra Grafana process.
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
        # Native provisioning can temporarily unprovision a dashboard
        # before importing it. Commit only a complete, stopped migration;
        # failure or interruption must leave the original ownership intact.
        copy_database(database, private_database)
        provisioning = work / "provisioning"
        for directory in ["dashboards", "datasources", "alerting", "plugins"]:
            (provisioning / directory).mkdir(parents=True, exist_ok=True)
        # Grafana deletes dashboards whose file-provider names disappear
        # from its config. Keep foreign providers registered but unwatched:
        # a nonexistent path makes their readers return without changes.
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
                    while pending:
                        if stop_requested:
                            raise RuntimeError("Dashboard reconciliation interrupted")
                        if process.poll() is not None:
                            raise RuntimeError("Private Grafana exited before dashboard reconciliation")
                        paths = dashboard_paths(private_database)
                        pending = {
                            uid: filename for uid, filename in pending.items()
                            if paths.get(uid) not in (filename, str(staged / filename))
                        }
                        if pending:
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

# Normal deleting provisioning sees only the configured files, at the same
# stable paths. In particular a disabled game is never recreated on restart.
stage_dashboards({
    uid for uid, source in sources.items()
    if source.name != "minecraft.json" or os.environ["GRAFANA_MINECRAFT_ENABLED"] == "1"
})
