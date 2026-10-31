{
  lib,
  pkgs,
}: let
  sourceRoot = ./fixtures/telemetry-ca-rotation;
  receiverSource = sourceRoot + "/system/secrets/receiver.yaml";
  nodeSource = sourceRoot + "/system/secrets/senders.json";
  certificateSource = sourceRoot + "/system/secrets/certificates.yaml";
  secret = path: key: sopsFile: format: {inherit path key sopsFile format;};
  node = name: {
    config = {
      laplace.services.telemetry.clientIdentity = {
        certificateFile = "/run/${name}/certificate";
        keyFile = "/run/${name}/key";
      };
      sops.secrets = {
        certificate = secret "/run/${name}/certificate" "nodes/${name}/certificate" certificateSource "yaml";
        key = secret "/run/${name}/key" "nodes/${name}/key" nodeSource "json";
      };
    };
  };
  cluster = {
    hosts = lib.genAttrs ["old-receiver" "new-receiver" "writer" "not-admitted"] (_: {telemetry = true;});
    activeServices.observability = {
      host = "new-receiver";
      settings = {
        sopsFile = "${receiverSource}";
        # Acknowledgement never creates admission, even after receiver relocation.
        expectedHosts = ["old-receiver" "new-receiver" "writer" "not-admitted"];
        writers = {
          old-receiver = {
            certificateSecret = "oldAllowed";
            sopsFile = null;
          };
          writer = {
            certificateSecret = "customAllowed";
            sopsFile = "${nodeSource}";
          };
          new-receiver = {
            certificateSecret = "unusedLocal";
            sopsFile = null;
          };
        };
      };
    };
  };
  nixosConfigurations = {
    old-receiver = node "old-receiver";
    writer = node "writer";
    new-receiver = lib.recursiveUpdate (node "new-receiver") {
      config = {
        laplace.services.observability.ingress = {
          enable = true;
          caFile = "/run/receiver/ca";
          writers = {
            old-receiver.certificateFile = "/run/receiver/old";
            writer.certificateFile = "/run/receiver/custom";
          };
        };
        sops.secrets = {
          ca = secret "/run/receiver/ca" "trust/client-ca" receiverSource "yaml";
          oldAllowed = secret "/run/receiver/old" "writers/old" receiverSource "yaml";
          customAllowed = secret "/run/receiver/custom" "admission/writer/certificate" nodeSource "json";
        };
      };
    };
  };
  planWith = overrides:
    import ../../system/services/telemetry/rotation-plan.nix ({
        inherit lib cluster nixosConfigurations sourceRoot;
      }
      // overrides);
  plan = planWith {};
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;
  badSource = path:
    planWith {
      cluster = lib.recursiveUpdate cluster {
        activeServices.observability.settings.writers.writer.sopsFile = path;
      };
    };
in
  assert plan.receiver.host == "new-receiver";
  assert builtins.attrNames plan.writers == ["old-receiver" "writer"];
  assert plan.receiver.ca
  == {
    file = "system/secrets/receiver.yaml";
    keyPath = "[\"trust\"][\"client-ca\"]";
  };
  assert plan.writers.old-receiver.clientCertificate
  == {
    file = "system/secrets/certificates.yaml";
    keyPath = "[\"nodes\"][\"old-receiver\"][\"certificate\"]";
  };
  assert plan.writers.writer.receiverCertificate
  == {
    file = "system/secrets/senders.json";
    keyPath = "[\"admission\"][\"writer\"][\"certificate\"]";
  };
  assert plan.files == ["system/secrets/certificates.yaml" "system/secrets/receiver.yaml" "system/secrets/senders.json" "system/secrets/telemetry-ca.yaml"];
  assert plan.writers.old-receiver.clientKey
  == {
    file = "system/secrets/senders.json";
    keyPath = "[\"nodes\"][\"old-receiver\"][\"key\"]";
  };
  assert !succeeds (planWith {
    nixosConfigurations = lib.recursiveUpdate nixosConfigurations {
      old-receiver.config.laplace.services.telemetry.clientIdentity.certificateFile = null;
    };
  });
  assert !succeeds (planWith {
    nixosConfigurations = lib.recursiveUpdate nixosConfigurations {
      old-receiver.config.laplace.services.telemetry.clientIdentity.keyFile = "/run/old-receiver/certificate";
    };
  });
  assert builtins.all (path: !succeeds (badSource path)) [
    "/outside/receiver.yaml"
    "/nix/store/unknown-receiver.yaml"
    "${toString sourceRoot}/system/secrets/../secrets/receiver.yaml"
    "${toString sourceRoot}/system/secrets/unsupported.ini"
  ];
    pkgs.runCommand "telemetry-ca-rotation-plan" {nativeBuildInputs = [pkgs.bash pkgs.coreutils];} ''
      source ${../../scripts/telemetry-rotation-paths.sh}
      repo="$PWD/repo"
      mkdir -p "$repo/system/secrets"
      printf 'mapping fixture\n' > "$repo/system/secrets/receiver.yaml"
      test "$(telemetry_rotation_source "$repo" system/secrets/receiver.yaml)" = "$repo/system/secrets/receiver.yaml"
      reject() {
        if telemetry_rotation_source "$1" "$2"; then
          echo "accepted unsafe rotation source: $1/$2" >&2
          exit 1
        fi
      }
      reject "$repo" ../receiver.yaml
      reject "$repo" system/secrets/../../receiver.yaml
      reject "$repo" /outside/receiver.yaml
      reject "$repo" system/secrets/missing.yaml
      reject /nix/store/fake-source system/secrets/receiver.yaml
      printf 'outside mapping fixture\n' > "$PWD/outside.yaml"
      ln -s "$PWD/outside.yaml" "$repo/system/secrets/symlink.yaml"
      reject "$repo" system/secrets/symlink.yaml
      mkdir -p "$PWD/linked/system"
      ln -s "$repo/system/secrets" "$PWD/linked/system/secrets"
      reject "$PWD/linked" system/secrets/receiver.yaml
      touch "$out"
    ''
