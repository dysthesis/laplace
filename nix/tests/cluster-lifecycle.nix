{
  pkgs,
  sopsModule,
}: let
  inherit (pkgs) lib;
  credentials = pkgs.runCommand "lifecycle-test-only-secrets" {nativeBuildInputs = [pkgs.age pkgs.sops];} ''
    mkdir -p "$out"
    age-keygen -o "$out/age.key"
    recipient=$(age-keygen -y "$out/age.key")
    printf '%s' '{"miniflux_admin":"ADMIN_USERNAME=lifecycle\nADMIN_PASSWORD=lifecycle-test-password\n","cloudflare_api_key":"not-a-real-token"}' > plaintext.json
    sops encrypt --age "$recipient" --input-type json --output-type yaml plaintext.json > "$out/secrets.yaml"
  '';
  fixtures = import ./personal-services.nix {
    inherit pkgs sopsModule;
    secretSource = "${credentials}/secrets.yaml";
  };
  services = enable: {
    inherit (fixtures.declarations) syncthing-server;
    miniflux =
      fixtures.declarations.miniflux
      // {
        inherit enable;
        settings = fixtures.declarations.miniflux.settings // {listenAddress = "[::]";};
      };
  };
  enabled = fixtures.evaluate (services true);
  # Use the local CA without changing the generated routes.
  localTLS = lib.replaceStrings [
    "tls {\n  dns cloudflare {env.CF_API_TOKEN}\n  resolvers 1.1.1.1\n}"
  ] ["tls internal"];
  generation = enable: let
    f = fixtures.evaluate (services enable);
  in {
    key = "personal-lifecycle-${
      if enable
      then "enabled"
      else "disabled"
    }";
    imports = [
      f.projection
      ({
        config,
        lib,
        ...
      }:
        import ../../system/tailnet/firewall.nix {
          inherit config lib;
          cluster = f.cluster;
        })
    ];
    config = {
      # The VM harness replaces fileSystems. Keep the Mnemosyne mounts for persistent state.
      virtualisation.fileSystems = f.config.fileSystems;
      services.caddy.virtualHosts =
        lib.mapAttrs (_: route: {
          extraConfig = lib.mkForce (localTLS route.extraConfig);
        })
        f.config.services.caddy.virtualHosts;
      # Removal must stop services when configuration changes do not trigger restarts.
      systemd.services = lib.optionalAttrs enable {
        miniflux = {
          restartIfChanged = false;
          reloadIfChanged = false;
        };
      };
    };
  };
  enabledGeneration = generation true;
  disabledGeneration = generation false;
  postgresData = enabled.config.services.postgresql.dataDir;
  backingData = "/nix/persist${postgresData}";
in
  pkgs.testers.runNixOSTest {
    name = "cluster-miniflux-lifecycle";
    nodes.machine = {lib, ...}: {
      imports = fixtures.commonModules ++ [enabledGeneration];
      networking.hostName = lib.mkForce "fixture";
      networking.nftables.enable = true;
      networking.firewall.enable = true;
      services.tailscale.interfaceName = "tailscale0";
      virtualisation.memorySize = 2048;
      virtualisation.diskSize = 4096;
      environment.etc."sops-test-age.key".source = "${credentials}/age.key";
      sops.age.keyFile = "/etc/sops-test-age.key";
      services.caddy.package = lib.mkForce pkgs.caddy;
      services.caddy.virtualHosts."unrelated.example.test".extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:8080
      '';
      services.nginx = {
        enable = true;
        virtualHosts."unrelated.example.test" = {
          listen = [
            {
              addr = "127.0.0.1";
              port = 8080;
            }
          ];
          locations."/".return = ''200 "unrelated service\\n"'';
        };
      };
      environment.systemPackages = [pkgs.curl pkgs.jq];
      specialisation.disabled.configuration = {
        disabledModules = [enabledGeneration];
        imports = [disabledGeneration];
      };
    };
    nodes.owner.environment.systemPackages = [pkgs.curl];
    nodes.denied.environment.systemPackages = [pkgs.curl];
    testScript = ''
      import json
      import shlex

      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("miniflux.service")
      machine.wait_for_unit("postgresql.service")
      try:
          machine.wait_for_unit("caddy.service")
      except Exception:
          print(machine.execute("${pkgs.caddy}/bin/caddy validate --adapter caddyfile --config /etc/caddy/caddy_config"))
          print(machine.succeed("journalctl -u caddy.service --no-pager; cat /etc/caddy/caddy_config; find /var/log/caddy -type f -exec cat {} ';'"))
          raise
      machine.wait_for_unit("nginx.service")
      machine.wait_for_open_port(8087)
      machine.wait_for_open_port(443)

      # The test uses Ethernet without Headscale or production enrolment.
      machine.succeed("ip link set eth1 down; ip link set eth1 name tailscale0; ip link set tailscale0 up")
      machine.succeed("ip addr add 100.64.1.10/24 dev tailscale0")
      machine.succeed("ip -6 addr add fd7a:115c:a1e0::10/64 dev tailscale0 nodad")
      for client, suffix in [(owner, "11"), (denied, "12")]:
          client.wait_for_unit("multi-user.target")
          client.succeed(f"ip addr add 100.64.1.{suffix}/24 dev eth1")
          client.succeed(f"ip -6 addr add fd7a:115c:a1e0::{suffix}/64 dev eth1 nodad")

      enabled_system = machine.succeed("readlink -f /run/current-system").strip()
      disabled_system = enabled_system + "/specialisation/disabled"
      curl = "curl --silent --show-error --fail --insecure --noproxy '*' "
      rss = curl + "--resolve rss.example.test:443:127.0.0.1 https://rss.example.test"
      unrelated = curl + "--resolve unrelated.example.test:443:127.0.0.1 https://unrelated.example.test/"
      api = rss + "/v1/categories -u lifecycle:lifecycle-test-password"
      marker = "durable-cluster-lifecycle-record"

      def direct(client, source, destination, allowed):
          command = (curl + "--max-time 3 --interface " + source
                     + " http://" + destination + ":8087/healthcheck")
          if allowed:
              assert "OK" in client.succeed(command)
          else:
              client.fail(command)

      def packet_checks(enabled):
          for client, suffix, authorised in [(owner, "11", True), (denied, "12", False)]:
              for source, destination in [
                  (f"100.64.1.{suffix}", "100.64.1.10"),
                  (f"fd7a:115c:a1e0::{suffix}", "[fd7a:115c:a1e0::10]"),
              ]:
                  direct(client, source, destination, enabled and authorised)
                  sync = (curl + "--max-time 3 --interface " + source
                          + " --resolve sync.example.test:443:" + destination
                          + " https://sync.example.test/")
                  if authorised:
                      client.succeed(sync)
                  else:
                      status = client.succeed(sync.replace("--fail ", "") + " -o /dev/null -w '%{http_code}'")
                      assert status == "403", status
                  command = (curl + "--max-time 3 --interface " + source
                             + " --resolve unrelated.example.test:443:" + destination
                             + " https://unrelated.example.test/")
                  assert "unrelated service" in client.succeed(command)
          rules = machine.succeed("nft list ruleset")
          assert ("tcp dport 8087" in rules) == enabled
          assert 'iifname "tailscale0"' in rules

      def database_identity():
          control = machine.succeed(
              "${enabled.config.services.postgresql.package}/bin/pg_controldata ${backingData}"
          )
          return next(line.split(":", 1)[1].strip() for line in control.splitlines()
                      if line.startswith("Database system identifier:"))

      with subtest("enabled recipe responds and writes a real application record"):
          machine.wait_until_succeeds(rss + "/healthcheck")
          assert "OK" in machine.succeed(curl + "http://127.0.0.1:8087/healthcheck")
          assert "unrelated service" in machine.succeed(unrelated)
          packet_checks(True)
          record = json.loads(machine.succeed(
              api + " -H 'Content-Type: application/json' -d "
              + shlex.quote(json.dumps({"title": marker}))
          ))
          record_id = record["id"]
          assert record["title"] == marker
          machine.succeed("test -s ${backingData}/PG_VERSION")
          machine.succeed("mountpoint /var/lib/postgresql")
          # Write the committed row to disk before the storage check.
          machine.succeed("su -s /bin/sh postgres -c 'psql -d miniflux -c CHECKPOINT'")
          cluster_identity = database_identity()
          nginx_invocation = machine.succeed(
              "systemctl show nginx.service -p InvocationID --value"
          ).strip()

      with subtest("disabled generation removes daemon and route, retains backing data"):
          machine.succeed(disabled_system + "/bin/switch-to-configuration test", timeout=180)
          machine.wait_until_succeeds("! systemctl is-active --quiet miniflux.service")
          machine.succeed("test ! -e /etc/systemd/system/miniflux.service")
          machine.succeed("test ! -e /etc/systemd/system/miniflux-dbsetup.service")
          machine.succeed("test ! -e /etc/systemd/system/postgresql.service")
          machine.fail(curl + "--connect-timeout 2 http://127.0.0.1:8087/healthcheck")
          live_routes = machine.succeed(curl + "http://127.0.0.1:2019/config/")
          assert "rss.example.test" not in live_routes
          assert "unrelated.example.test" in live_routes
          machine.fail(rss + "/healthcheck")
          assert "unrelated service" in machine.succeed(unrelated)
          packet_checks(False)
          assert machine.succeed("systemctl show nginx.service -p InvocationID --value").strip() == nginx_invocation
          machine.succeed("test -s ${backingData}/PG_VERSION")
          machine.succeed("test -s ${backingData}/global/pg_control")
          machine.succeed("test -n \"$(find ${backingData}/base -type f -print -quit)\"")
          machine.fail("mountpoint /var/lib/postgresql")
          assert database_identity() == cluster_identity

      with subtest("reenabling the same recipe restores the same durable record"):
          machine.succeed(enabled_system + "/bin/switch-to-configuration test", timeout=180)
          machine.wait_for_unit("postgresql.service")
          machine.wait_for_unit("miniflux.service")
          machine.wait_until_succeeds(rss + "/healthcheck")
          machine.succeed("mountpoint /var/lib/postgresql")
          assert database_identity() == cluster_identity
          records = json.loads(machine.succeed(api))
          assert any(r["id"] == record_id and r["title"] == marker for r in records), records
          assert "unrelated service" in machine.succeed(unrelated)
          packet_checks(True)
          live_routes = machine.succeed(curl + "http://127.0.0.1:2019/config/")
          assert "rss.example.test" in live_routes
    '';
  }
