# Real Grafana provisioning across retained-state cutovers; no production secrets.
{
  pkgs,
  lib,
  inputs,
  self,
}: let
  fixture = extraModules:
    (import ./service-fixtures.nix {inherit lib inputs self extraModules;}).observability;
  enabled = fixture [];
  disabled = fixture [{laplace.services.minecraft.enable = lib.mkForce false;}];
  absent = fixture [{laplace.services.minecraft = lib.mkForce null;}];
  current = config: {
    settings = config.services.grafana.provision.dashboards.settings;
    prepare = lib.getExe config.system.build.observabilityDashboardOwnership;
    environment = config.systemd.services.grafana.environment;
  };
  generations = pkgs.writeText "grafana-dashboard-generations.json" (builtins.toJSON {
    # Before placement-driven provisioning, this provider owned all four files.
    baseline.settings = {
      apiVersion = 1;
      providers = [
        {
          name = "Laplace";
          type = "file";
          disableDeletion = true;
          updateIntervalSeconds = 30;
          options.path = ../../system/services/observability/dashboards;
        }
      ];
    };
    enabled = current enabled;
    disabled = current disabled;
    absent = current absent;
  });
in
  pkgs.runCommand "observability-dashboard-lifecycle" {nativeBuildInputs = [pkgs.python3];} ''
    python - <<'PY'
    import base64
    from contextlib import closing, contextmanager
    import json
    import os
    from pathlib import Path
    import socket
    import sqlite3
    import subprocess
    import tempfile
    import time
    import urllib.error
    import urllib.request

    generations = json.loads(Path("${generations}").read_text())
    ordinary_uids = ["laplace-fleet", "laplace-journal", "argus-self"]
    game_uid = "minecraft-retirement-home"
    manual_uid = "retained-manual-dashboard"
    foreign_uid = "retained-foreign-dashboard"
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    auth = base64.b64encode(b"admin:dashboard-test-password").decode()

    def api(path, payload=None, expected=200, method=None):
        request = urllib.request.Request(
            "http://127.0.0.1:3000" + path,
            data=None if payload is None else json.dumps(payload).encode(),
            headers={"Authorization": "Basic " + auth, "Content-Type": "application/json"},
            method=method,
        )
        try:
            response = opener.open(request, timeout=5)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            body = response.read().decode()
            assert response.code == expected, (path, response.code, body)
            return json.loads(body)

    def dashboard(uid):
        return api("/api/dashboards/uid/" + uid)

    def preparation_environment(state, generation):
        return os.environ | generations[generation]["environment"] | {
            "GRAFANA_STATE_DIR": str(state),
            "GRAFANA_DATABASE_PATH": str(state / "grafana.db"),
            "GRAFANA_SECRET_KEY": "disposable-dashboard-test-secret",
            "RUNTIME_DIRECTORY": str(state / "runtime"),
        }

    def assert_private_stopped(state):
        private_socket = state / "runtime" / "dashboard-ownership" / "grafana.sock"
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            assert connection.connect_ex(str(private_socket)) != 0, "Private Grafana was left running"

    def database_snapshot(state):
        with closing(sqlite3.connect((state / "grafana.db").as_uri() + "?mode=ro", uri=True)) as db:
            return tuple(db.iterdump())

    def foreign_record(state):
        path = state / "grafana.db"
        if not path.exists():
            return None
        with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)) as db:
            return db.execute(
                'SELECT resource_version, value FROM resource WHERE namespace = ? AND "group" = ? '
                'AND resource = ? AND name = ?',
                ("default", "dashboard.grafana.app", "dashboards", foreign_uid),
            ).fetchone()

    def copy_database(source, destination):
        with closing(sqlite3.connect(source.as_uri() + "?mode=ro", uri=True)) as source_db:
            with closing(sqlite3.connect(destination)) as destination_db:
                source_db.backup(destination_db)

    def prepare(state, generation, timeout=130, runtime=None):
        foreign_before = foreign_record(state)
        environment = preparation_environment(state, generation)
        if runtime is not None:
            environment["RUNTIME_DIRECTORY"] = str(runtime)
        subprocess.run([generations[generation]["prepare"]], env=environment, check=True, timeout=timeout)
        assert_private_stopped(state)
        database = state / "grafana.db"
        if database.exists():
            with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)) as db:
                assert db.execute(
                    "SELECT 1 FROM server_lock WHERE operation_uid = ?",
                    ("provisioning_dashboards",),
                ).fetchone() is None, "Preparation retained a provisioning lease"
        # Check before the normal Foreign provider could hide a destructive
        # private pass by importing its dashboard again with a different ID.
        assert foreign_record(state) == foreign_before

    def assert_bounded_preparation(state, generation):
        before = database_snapshot(state)
        bootstrap = {name: (state / name).read_bytes()
                     for name in ["secret-key", "bootstrap-admin-password"]}
        # A stable database must not need any private-process runtime directory.
        # Using a file here makes an unwanted extra migration fail immediately.
        unused = state / "unused-runtime"
        unused.write_text("No private startup on a stable database\n")
        for _ in range(3):
            prepare(state, generation, timeout=5, runtime=unused)
            assert database_snapshot(state) == before
        assert {name: (state / name).read_bytes() for name in bootstrap} == bootstrap
        assert unused.read_text() == "No private startup on a stable database\n"

    def interrupt_preparation(state):
        before = database_snapshot(state)
        environment = preparation_environment(state, "disabled")
        broken = state / "broken-sources"
        broken.mkdir()
        for source in Path(environment["GRAFANA_DASHBOARD_SOURCES"]).glob("*.json"):
            content = json.loads(source.read_text())
            if content["uid"] == game_uid:
                # A real failed import keeps reconciliation pending until stopped.
                content["title"] = ""
            (broken / source.name).write_text(json.dumps(content))
        environment["GRAFANA_DASHBOARD_SOURCES"] = str(broken)
        log = state / "interrupted-preparation.log"
        try:
            with log.open("w") as output:
                process = subprocess.Popen(
                    [generations["disabled"]["prepare"]], env=environment,
                    stdout=output, stderr=subprocess.STDOUT,
                )
                try:
                    private_socket = state / "runtime" / "dashboard-ownership" / "grafana.sock"
                    deadline = time.monotonic() + 90
                    while True:
                        assert process.poll() is None, "Preparation exited before interruption"
                        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                            if connection.connect_ex(str(private_socket)) == 0:
                                assert private_socket.stat().st_mode & 0o777 == 0o600
                                break
                        assert time.monotonic() < deadline, "Private Grafana did not listen"
                        time.sleep(0.25)
                    process.terminate()
                    assert process.wait(timeout=25) != 0
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=25)
            assert_private_stopped(state)
            # Failed preparation must not commit partially changed ownership.
            assert database_snapshot(state) == before
            assert (state / "dashboards" / "minecraft.json").exists()
        except BaseException:
            print(log.read_text())
            raise

    @contextmanager
    def running(state, generation):
        settings = json.loads(json.dumps(generations[generation]["settings"]))
        if generation != "baseline":
            # Execute the exact production ExecStartPre helper with disposable
            # state and secrets, retaining its real database migration behavior.
            prepare(state, generation)
            settings["providers"][0]["options"]["path"] = str(state / "dashboards")
        foreign = state / "foreign-dashboards"
        foreign.mkdir(parents=True, exist_ok=True)
        (foreign / "minecraft.json").write_text(json.dumps({
            "uid": foreign_uid,
            "title": "Retained foreign provisioned dashboard",
            "schemaVersion": 39,
            "panels": [],
        }))
        settings["providers"].append({
            "name": "Foreign",
            "type": "file",
            "disableDeletion": False,
            "options": {"path": str(foreign)},
        })
        provisioning = state / "provisioning"
        for directory in ["dashboards", "datasources", "alerting", "plugins"]:
            (provisioning / directory).mkdir(parents=True, exist_ok=True)
        (provisioning / "dashboards" / "providers.yaml").write_text(
            json.dumps(settings)
        )
        config = state / "grafana.ini"
        config.write_text(f"""
    [paths]
    data = {state}/data
    logs = {state}/logs
    plugins = {state}/plugins
    provisioning = {provisioning}
    [server]
    http_addr = 127.0.0.1
    http_port = 3000
    [database]
    type = sqlite3
    path = {state}/grafana.db
    [security]
    admin_user = admin
    admin_password = dashboard-test-password
    secret_key = disposable-dashboard-test-secret
    [analytics]
    reporting_enabled = false
    check_for_updates = false
    check_for_plugin_updates = false
    [plugins]
    preinstall_disabled = true
    public_key_retrieval_disabled = true
    [unified_alerting]
    enabled = false
    [log]
    mode = console
    level = warn
    """)
        log = state / (generation + ".log")
        try:
            with log.open("w") as output:
                process = subprocess.Popen(
                    ["${lib.getExe enabled.services.grafana.package}", "server",
                     "-homepath", "${enabled.services.grafana.package}/share/grafana", "-config", str(config)],
                    stdout=output, stderr=subprocess.STDOUT,
                )
                try:
                    deadline = time.monotonic() + 90
                    while True:
                        assert process.poll() is None, "Grafana exited during startup"
                        try:
                            if api("/api/health")["database"] == "ok":
                                break
                        except (OSError, urllib.error.URLError):
                            pass
                        assert time.monotonic() < deadline, "Grafana did not become healthy"
                        time.sleep(0.25)
                    yield
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
        except BaseException:
            print(log.read_text())
            raise

    def assert_game(enabled):
        if enabled:
            game = dashboard(game_uid)
            assert game["meta"]["provisioned"], game
            assert game["meta"]["provisionedExternalId"] == "minecraft.json", game
            return game["dashboard"]["id"]
        api("/api/dashboards/uid/" + game_uid, expected=404)

    def assert_retained(originals, manual, annotation_id):
        assert api("/api/org")["name"] == "Renamed Laplace organization"
        for uid, original in originals.items():
            current = dashboard(uid)
            assert current["meta"]["provisioned"], current
            assert current["meta"]["provisionedExternalId"] == original["meta"]["provisionedExternalId"], current
            for key in ["id", "uid", "title", "panels"]:
                assert current["dashboard"][key] == original["dashboard"][key], (uid, key)
        current = dashboard(manual_uid)
        assert not current["meta"]["provisioned"], current
        assert current["dashboard"] == manual["dashboard"], current
        annotations = api("/api/annotations?dashboardUID=laplace-fleet")
        assert any(item["id"] == annotation_id
                   and item["text"] == "Retained fleet annotation"
                   and item["dashboardId"] == originals["laplace-fleet"]["dashboard"]["id"]
                   for item in annotations), annotations
        uids = [item["uid"] for item in api("/api/search?type=dash-db")]
        assert len(uids) == len(set(uids)), uids
        assert set(uids) - {game_uid} == set(originals) | {manual_uid}, uids

    with tempfile.TemporaryDirectory() as temporary:
        for generation in ["enabled", "disabled", "absent"]:
            state = Path(temporary) / ("fresh-" + generation)
            with running(state, generation):
                assert_game(generation == "enabled")
                for uid in ordinary_uids:
                    assert dashboard(uid)["meta"]["provisioned"]
            assert not (state / "runtime").exists(), "Fresh startup ran a private migration"
            assert_bounded_preparation(state, generation)

        for first in ["disabled", "absent", "enabled"]:
            # The organization display name changes before the first cutover.
            # All later starts retain the same database, including its user data.
            state = Path(temporary) / first
            with running(state, "baseline"):
                originals = {uid: dashboard(uid) for uid in ordinary_uids + [foreign_uid]}
                game_id = assert_game(True)
                annotation_id = api("/api/annotations", {
                    "dashboardUID": "laplace-fleet",
                    "time": int(time.time() * 1000),
                    "text": "Retained fleet annotation",
                })["id"]
                api("/api/dashboards/db", {
                    "dashboard": {
                        "uid": manual_uid,
                        "title": "Retained ordinary dashboard",
                        "description": "Durable user-created data, outside file provisioning",
                        "schemaVersion": 39,
                        "tags": ["retained-state-regression"],
                        "panels": [{
                            "id": 1,
                            "type": "text",
                            "title": "Durable note",
                            "gridPos": {"h": 4, "w": 12, "x": 0, "y": 0},
                            "options": {"mode": "markdown", "content": "Keep this dashboard and its data"},
                        }],
                    },
                    "overwrite": False,
                })
                manual = dashboard(manual_uid)
                api("/api/org", {"name": "Renamed Laplace organization"}, method="PUT")
                assert_retained(originals, manual, annotation_id)
            assert (state / "grafana.db").is_file()
            legacy = state / "legacy.db"
            copy_database(state / "grafana.db", legacy)
            if first == "disabled":
                interrupt_preparation(state)

            with running(state, first):
                current_game_id = assert_game(first == "enabled")
                if first == "enabled":
                    assert current_game_id == game_id
                assert_retained(originals, manual, annotation_id)
            previous_game_id = current_game_id
            assert_bounded_preparation(state, first)

            # Disabled and absent declarations both reach real provisioning,
            # including when they are the first cutover from historical state.
            for generation in ["enabled", "disabled", "enabled", "absent"]:
                with running(state, generation):
                    current_game_id = assert_game(generation == "enabled")
                    if previous_game_id is not None and current_game_id is not None:
                        assert current_game_id == previous_game_id
                    previous_game_id = current_game_id
                    assert_retained(originals, manual, annotation_id)
                assert_bounded_preparation(state, generation)

            if first == "disabled":
                # Restoring historical ownership must trigger adoption again,
                # even though this filesystem has already completed a cutover.
                copy_database(legacy, state / "grafana.db")
                with running(state, "enabled"):
                    assert assert_game(True) == game_id
                    assert_retained(originals, manual, annotation_id)
                assert_bounded_preparation(state, "enabled")
                with running(state, "disabled"):
                    assert_game(False)
                    assert_retained(originals, manual, annotation_id)
                assert_bounded_preparation(state, "disabled")
    PY
    touch "$out"
  ''
