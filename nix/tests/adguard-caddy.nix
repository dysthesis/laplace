{
  pkgs,
  sopsModule,
}: let
  inherit (pkgs) lib;
  fixtures = import ./personal-services.nix {inherit pkgs sopsModule;};
  # Use the local CA without changing the generated routes.
  localTLS = lib.replaceStrings [
    "tls {\n  dns cloudflare {env.CF_API_TOKEN}\n  resolvers 1.1.1.1\n}"
  ] ["tls internal"];
  testCase = fixture: service: redirects: let
    config =
      (import "${pkgs.path}/nixos/lib/eval-config.nix" {
        system = pkgs.stdenv.hostPlatform.system;
        modules =
          fixture.modules
          ++ [
            {
              services.caddy = {
                package = lib.mkForce pkgs.caddy;
                # The sandbox cannot bind privileged ports.
                httpPort = 18080;
                httpsPort = 18443;
                globalConfig = lib.mkAfter ''
                  admin 127.0.0.1:12019
                  skip_install_trust
                  servers {
                    max_header_size 8KB
                  }
                '';
                virtualHosts =
                  lib.mapAttrs (_: route: {
                    extraConfig = lib.mkForce (localTLS route.extraConfig);
                    logFormat = lib.mkForce "output stderr";
                  })
                  fixture.config.services.caddy.virtualHosts;
              };
            }
          ];
      }).config;
  in {
    name = "adguard-${toString fixture.cluster.services.adguardhome.settings.port}";
    configFile = toString config.services.caddy.configFile;
    domain = fixture.cluster.endpoints.${service}.https.domain;
    httpEndpoint =
      if redirects
      then fixture.cluster.endpoints.${service}.http
      else null;
    inherit (config.services.caddy) httpPort httpsPort;
    inherit redirects;
  };
  cases = [
    (testCase fixtures.adguardCaddy.on80 "adguardhome" false)
    (testCase fixtures.adguardCaddy.on8080 "miniflux" true)
  ];
  casesFile = pkgs.writeText "adguard-caddy-cases.json" (builtins.toJSON cases);
in
  pkgs.runCommand "adguard-caddy-redirects" {nativeBuildInputs = [pkgs.python3];} ''
    python - <<'PY'
    import http.client
    import json
    import os
    from pathlib import Path
    import socket
    import ssl
    import subprocess
    import time

    tls = ssl.create_default_context()
    tls.check_hostname = False
    tls.verify_mode = ssl.CERT_NONE

    def request(case, *, secure=False, path="/", headers=None):
        port = case["httpsPort"] if secure else case["httpPort"]
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=2)
        try:
            if secure:
                connection.sock = tls.wrap_socket(
                    socket.create_connection(("127.0.0.1", port), timeout=2),
                    server_hostname=case["domain"],
                )
            connection.request("GET", path, headers={"Host": case["domain"], **(headers or {})})
            response = connection.getresponse()
            response.read()
            return response.status, dict(response.getheaders())
        finally:
            connection.close()

    for case in json.loads(Path("${casesFile}").read_text()):
        directory = Path(case["name"]).resolve()
        directory.mkdir()
        environment = dict(os.environ, HOME=str(directory),
                           XDG_DATA_HOME=str(directory / "data"),
                           XDG_CONFIG_HOME=str(directory / "config"))
        log_path = directory / "caddy.log"
        with log_path.open("wb") as log:
            process = subprocess.Popen(
                ["${lib.getExe pkgs.caddy}", "run", "--adapter", "caddyfile", "--config", case["configFile"]],
                env=environment, stdout=log, stderr=subprocess.STDOUT,
            )
            try:
                # An open admin socket does not prove that HTTPS is ready.
                for _ in range(100):
                    assert process.poll() is None, "Caddy exited before becoming ready"
                    try:
                        status, _ = request(case, secure=True)
                    except (OSError, http.client.HTTPException):
                        time.sleep(0.1)
                    else:
                        assert status != 431
                        break
                else:
                    raise AssertionError("Caddy did not become ready")

                if case["redirects"]:
                    assert case["httpEndpoint"]["port"] == 80
                    path = "/feeds?tag=redirect-regression"
                    status, headers = request(case, path=path)
                    assert status == 308, (status, headers)
                    assert headers["Location"] == "https://" + case["domain"] + path, headers
                else:
                    try:
                        request(case)
                    except ConnectionRefusedError:
                        pass
                    else:
                        raise AssertionError("Caddy opened the HTTP listener reserved for AdGuard")

                status, _ = request(case, secure=True, headers={"X-Oversized": "x" * 32768})
                assert status == 431, (case["name"], status)
                print(case["name"] + ": listener and global-option behaviour passed")
            except BaseException:
                print(log_path.read_text())
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    PY
    touch "$out"
  ''
