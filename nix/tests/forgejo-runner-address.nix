{pkgs}: let
  inherit (pkgs) lib;
  instanceName = "fixture";
  oldURL = "http://127.0.0.1:18118";
  newURL = "http://127.0.0.1:18119";
  runner = {
    package = pkgs.forgejo-runner;
    tokenFile = "/disposable-registration.env";
    labels = ["nix:host" "secondary:host"];
    hostPackages = [];
    settings.cache.enabled = false;
  };
  evaluate = modules:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules =
        [
          {
            nixpkgs.pkgs = pkgs;
            system.stateVersion = "26.05";
          }
        ]
        ++ modules;
    }).config;
  configured = url: (evaluate [
    ../../modules/mnemosyne
    ../../system/services/forgejo-runner
    {
      laplace.services.forgejo-runner =
        runner
        // {
          inherit instanceName url;
          enable = true;
        };
    }
  ]);
  configuration = configured newURL;
  after = configuration.systemd.services."gitea-runner-${instanceName}";
  unit = configuration.systemd.units."gitea-runner-${instanceName}.service".text;
  startup = after.serviceConfig.ExecStartPre;
  fixture = pkgs.writeText "forgejo-runner-address-fixture.json" (builtins.toJSON {
    inherit instanceName oldURL newURL;
    inherit (runner) labels;
    inherit startup;
    start = lib.removePrefix "ExecStart=" (lib.findFirst
      (line: lib.hasPrefix "ExecStart=" line)
      (throw "Runner unit has no ExecStart")
      (lib.splitString "\n" unit));
    environment = after.environment // {PATH = lib.makeBinPath after.path;};
  });
in
  pkgs.runCommand "forgejo-runner-address" {nativeBuildInputs = [pkgs.python3];} ''
    python - <<'PY'
    from contextlib import suppress
    import hashlib
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    import json
    import os
    from pathlib import Path
    import queue
    import shlex
    import signal
    import stat
    import subprocess
    import tempfile
    import threading
    from urllib.parse import urlsplit

    fixture = json.loads(Path("${fixture}").read_text())
    requests = queue.Queue()
    invalid_registration_token = "expired-disposable-one-shot-token"

    class AddressProbe(BaseHTTPRequestHandler):
        def do_POST(self):
            self.rfile.read(int(self.headers.get("Content-Length", "0")))
            requests.put((self.path, self.headers))
            # A 401 response is sufficient for checks of the connection address and saved credentials.
            body = b'{"code":"unauthenticated","message":"disposable address probe"}'
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    def run(command, state, *, check=True):
        instance = state / fixture["instanceName"]
        environment = os.environ | fixture["environment"] | {
            "HOME": str(instance),
            "STATE_DIRECTORY": str(state),
            "TOKEN": invalid_registration_token,
            "FORGEJO_CLIENT_TIMEOUT": "3",
            "NO_PROXY": "127.0.0.1,localhost",
            "no_proxy": "127.0.0.1,localhost",
        }
        process = subprocess.Popen(
            command, cwd=instance, env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            start_new_session=True,
        )
        try:
            output, _ = process.communicate(timeout=15)
            assert not check or process.returncode == 0, output
            return process.returncode, output
        finally:
            # Registration can start a child process.
            with suppress(ProcessLookupError):
                os.killpg(process.pid, signal.SIGKILL)
            process.wait()

    def startup(state, *, check=True):
        for helper in fixture["startup"]:
            code, output = run([helper], state, check=check)
            if code:
                return code, output
        return 0, ""

    endpoint = urlsplit(fixture["newURL"])
    with ThreadingHTTPServer((endpoint.hostname, endpoint.port), AddressProbe) as probe:
        thread = threading.Thread(target=probe.serve_forever, daemon=True)
        thread.start()
        try:
            with tempfile.TemporaryDirectory() as directory:
                state = Path(directory)
                state.chmod(0o700)
                instance = state / fixture["instanceName"]
                instance.mkdir(mode=0o700)
                registration = instance / ".runner"
                original = {
                    "WARNING": "disposable existing registration",
                    "id": 9007199254740993,
                    "uuid": "5f153a6f-c9d4-447d-a6a3-d523eab7124d",
                    "name": fixture["instanceName"],
                    "token": "durable-runner-credential-not-the-registration-token",
                    "address": fixture["oldURL"],
                    "labels": fixture["labels"],
                    "future": {"opaque": [None, True, 9007199254740993, "retained\nvalue"]},
                }
                registration.write_text(json.dumps(original) + "\n")
                registration.chmod(0o600)
                gates = {
                    ".token-hash": hashlib.sha256(invalid_registration_token.encode()).hexdigest(),
                    ".labels": "\n".join(sorted(fixture["labels"])) + "\n",
                }
                for name, content in gates.items():
                    path = instance / name
                    path.write_text(content)
                    path.chmod(0o600)

                # An address change must not start registration with an invalid one-shot token.
                with registration.open() as retained:
                    old_stat = os.fstat(retained.fileno())
                    startup(state)
                    updated_stat = registration.stat()
                    assert old_stat.st_ino != updated_stat.st_ino
                    assert json.load(retained) == original, "Reconciliation overwrote the old inode"
                    assert (updated_stat.st_uid, updated_stat.st_gid) == (old_stat.st_uid, old_stat.st_gid)
                expected = original | {"address": fixture["newURL"]}
                assert json.loads(registration.read_text()) == expected
                assert stat.S_IMODE(registration.stat().st_mode) == 0o600
                assert not list(instance.glob(".runner.*")), "Private temporary file was left behind"
                assert requests.empty(), "An existing identity unexpectedly tried to register"
                for name, content in gates.items():
                    assert (instance / name).read_text() == content

                # An unchanged address does not rewrite or replace private state.
                content = registration.read_bytes()
                unchanged = registration.stat()
                startup(state)
                assert registration.read_bytes() == content
                assert registration.stat().st_ino == unchanged.st_ino
                assert registration.stat().st_mtime_ns == unchanged.st_mtime_ns

                # A failed JSON update must not damage the saved registration.
                registration.write_text('{"token":"retained-invalid-state",')
                broken = registration.read_bytes()
                code, _ = startup(state, check=False)
                assert code != 0
                assert registration.read_bytes() == broken
                assert not list(instance.glob(".runner.*"))
                registration.write_bytes(content)

                # The daemon must use the saved address and identity.
                code, output = run(shlex.split(fixture["start"]), state, check=False)
                path, headers = requests.get(timeout=2)
                assert path == "/api/actions/runner.v1.RunnerService/Declare", (path, output)
                assert headers["x-runner-uuid"] == original["uuid"]
                assert headers["x-runner-token"] == original["token"]
                assert headers["x-runner-token"] != invalid_registration_token
                assert headers["User-Agent"].startswith("forgejo-runner/")
                assert code != 0, "The disposable endpoint should reject authentication"
                assert json.loads(registration.read_text()) == expected
                assert requests.empty(), "Unexpected extra registration or daemon request"
        finally:
            probe.shutdown()
            thread.join(timeout=5)
    PY
    touch "$out"
  ''
