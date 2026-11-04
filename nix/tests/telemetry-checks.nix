{
  pkgs,
  lib,
  nixosConfigurations,
}: {
  telemetry-boot-persistence = let
    talos = nixosConfigurations.talos.config;
    ready = talos.systemd.services.telemetry-journal-ready;
    vmagent = talos.systemd.services.vmagent;
    journalUpload = talos.systemd.services.systemd-journal-upload;
  in
    pkgs.runCommand "telemetry-boot-persistence-check" {} ''
      test ${lib.escapeShellArg (lib.boolToString ready.unitConfig.DefaultDependencies)} = false
      test ${lib.escapeShellArg vmagent.unitConfig.RequiresMountsFor} = /var/cache/private/vmagent
      test ${lib.escapeShellArg journalUpload.unitConfig.RequiresMountsFor} = /var/lib/private/systemd/journal-upload
      touch $out
    '';

  telemetry-ca-cleanup = pkgs.runCommand "telemetry-ca-cleanup" {nativeBuildInputs = [pkgs.bash pkgs.coreutils];} ''
    mkdir bin
    mkfifo finish
    cat > bin/openssl <<'SH'
    #!${pkgs.runtimeShell}
    if [[ $1 == genpkey ]]; then
      printf '%s\n' "$5" > "$TEST_ROOT/key-path"
      read -r _ < "$TEST_ROOT/finish"
      exit 0
    fi
    touch "$TEST_ROOT/continued"
    exit 1
    SH
    chmod +x bin/openssl
    TEST_ROOT="$PWD" PATH="$PWD/bin:$PATH" bash ${../../scripts/generate-telemetry-ca.sh} &
    generator=$!
    while [[ ! -s key-path ]]; do
      kill -0 "$generator"
      sleep 0.05
    done
    kill -TERM "$generator"
    printf 'finish\n' > finish
    if wait "$generator"; then
      echo "CA generation succeeded after interruption" >&2
      exit 1
    fi
    test ! -e continued
    test ! -d "$(dirname "$(cat key-path)")"
    touch "$out"
  '';

  telemetry-endpoint-contract = let
    endpoints = lib.laplace.telemetry.endpoints;
    talosConfigWith = settings:
      (nixosConfigurations.talos.extendModules {
        modules = [{laplace.services.telemetry = settings;}];
      }).config;
    telemetryWith = settings: (talosConfigWith settings).laplace.services.telemetry;
    metricsOverride = telemetryWith {
      metrics.origin = "https://metrics.example.net/";
      metrics.remoteWriteUrl = "https://metrics.example.net/write";
    };
    journalOverride = telemetryWith {
      journal.origin = "https://logs.example.net/";
      journal.url = "https://logs.example.net/journald";
    };
    metricsDisabled = telemetryWith {
      metrics.enable = false;
      metrics.origin = "https://metrics.example.net/";
    };
    journalDisabled = telemetryWith {
      journal.enable = false;
      journal.origin = "https://logs.example.net/";
    };
    paths = endpoints {
      writer = "canary";
      metricsOrigin = "https://metrics.example.net/";
      journalOrigin = "https://logs.example.net/";
    };
    badMetrics = builtins.tryEval ((endpoints {
      writer = "talos";
      metricsOrigin = "https://metrics.example.net/";
    }).metricsUrl);
    badJournal = builtins.tryEval ((endpoints {
      writer = "talos";
      journalOrigin = "https://logs.example.net/";
    }).journalBaseUrl);
    badWriter = builtins.tryEval ((endpoints {writer = "not/a-writer";}).journalUploadPath);
    alternate = talosConfigWith {
      writer = "canary";
      metrics.origin = "https://metrics.example.net:10443";
      journal.origin = "https://logs.example.net:10444";
    };
    fullOverrides = talosConfigWith {
      writer = "canary";
      metrics.origin = "https://metrics.example.net:10443";
      journal.origin = "https://logs.example.net:10444";
      metrics.remoteWriteUrl = "https://override.example.net/remote/write?tenant=1";
      journal.url = "https://override.example.net/archive/journald/";
    };
    isolatedAssertions = settings:
      (lib.evalModules {
        specialArgs.pkgs = {cacert = "/fixture/cacert";};
        modules = [
          ../../system/services/telemetry
          {
            options = {
              networking.hostName = lib.mkOption {
                type = lib.types.str;
                default = "talos";
              };
              services = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = {};
              };
              systemd = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = {};
              };
              mnemosyne.dirs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
              };
              assertions = lib.mkOption {
                type = lib.types.listOf lib.types.anything;
                default = [];
              };
            };
            config.laplace.services.telemetry = settings;
          }
        ];
      }).config.assertions;
    disabledMetricsAssertions = isolatedAssertions {
      enable = true;
      metrics = {
        enable = false;
        origin = "https://metrics.example.net/";
        keyFile = "/fixture/metrics.key";
        certificateFile = "/fixture/metrics.crt";
      };
      journal.enable = false;
    };
    disabledJournalAssertions = isolatedAssertions {
      enable = true;
      metrics.enable = false;
      journal = {
        enable = false;
        origin = "https://logs.example.net/";
        keyFile = "/fixture/journal.key";
        certificateFile = "/fixture/journal.crt";
      };
    };
    enabledMetricHttp = isolatedAssertions {
      enable = true;
      metrics = {
        remoteWriteUrl = "http://127.0.0.1:18844/write";
        keyFile = "/fixture/metrics.key";
        certificateFile = "/fixture/metrics.crt";
      };
      journal.enable = false;
    };
    enabledJournalHttp = isolatedAssertions {
      enable = true;
      metrics.enable = false;
      journal = {
        url = "http://127.0.0.1:18844/journald";
        keyFile = "/fixture/journal.key";
        certificateFile = "/fixture/journal.crt";
      };
    };
    disabledUnpaired = isolatedAssertions {
      enable = true;
      metrics = {
        enable = false;
        certificateFile = "/fixture/metrics.crt";
      };
      journal.enable = false;
    };
    enabledNull = isolatedAssertions {
      enable = true;
      metrics.remoteWriteUrl = null;
      journal.enable = false;
    };
  in
    assert lib.all (a: a.assertion) disabledMetricsAssertions;
    assert lib.all (a: a.assertion) disabledJournalAssertions;
    assert !(lib.all (a: a.assertion) enabledMetricHttp);
    assert !(lib.all (a: a.assertion) enabledJournalHttp);
    assert !(lib.all (a: a.assertion) disabledUnpaired);
    assert !(lib.all (a: a.assertion) enabledNull);
    assert alternate.services.vmagent.remoteWrite.url == "https://metrics.example.net:10443/canary/metrics";
    assert alternate.services.journald.upload.settings.Upload.URL == "https://logs.example.net:10444/canary/journald";
    assert alternate.services.vmagent.prometheusConfig.global.external_labels.host == "talos";
    assert builtins.elem "VL-Extra-Fields: source=talos" alternate.services.journald.upload.settings.Upload.Header;
    assert fullOverrides.services.vmagent.remoteWrite.url == "https://override.example.net/remote/write?tenant=1";
    assert fullOverrides.services.journald.upload.settings.Upload.URL == "https://override.example.net/archive/journald/";
    assert metricsOverride.journal.url == "https://telemetry.dysthesis.com:8444/talos/journald";
    assert journalOverride.metrics.remoteWriteUrl == "https://telemetry.dysthesis.com:8443/talos/metrics";
    assert metricsDisabled.journal.url == "https://telemetry.dysthesis.com:8444/talos/journald";
    assert journalDisabled.metrics.remoteWriteUrl == "https://telemetry.dysthesis.com:8443/talos/metrics";
    assert paths.metricsPath == "/canary/metrics";
    assert paths.journalUploadPath == "/canary/journald/upload";
    assert !badMetrics.success;
    assert !badJournal.success;
    assert !badWriter.success;
      pkgs.runCommand "telemetry-endpoint-contract-check" {} "touch $out";
}
