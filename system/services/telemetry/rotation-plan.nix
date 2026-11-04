{
  lib,
  cluster,
  nixosConfigurations,
  sourceRoot,
}: let
  sourceDirectory = sourceRoot + "/system/secrets";
  sources =
    lib.mapAttrsToList (name: _: {
      file = "system/secrets/${name}";
      path = sourceDirectory + "/${name}";
    }) (lib.filterAttrs (name: type:
      type == "regular" && builtins.match "[A-Za-z0-9][A-Za-z0-9._-]*\\.(yaml|json)" name != null)
    (builtins.readDir sourceDirectory));
  sourceFile = path: let
    # Manifest paths can be copied file-store strings, not paths below outPath.
    matches = builtins.filter (source: toString path == toString source.path || toString path == "${source.path}") sources;
  in
    assert lib.assertMsg (builtins.length matches == 1) "telemetry rotation requires an unambiguous repository system/secrets/*.{yaml,json} source: ${toString path}";
      (builtins.head matches).file;
  target = secret:
    assert lib.assertMsg (builtins.elem secret.format ["yaml" "json"] && secret.key != "") "telemetry rotation requires a named YAML or JSON SOPS key"; {
      file = sourceFile secret.sopsFile;
      keyPath = lib.concatMapStrings (key: "[${builtins.toJSON key}]") (lib.splitString "/" secret.key);
    };
  credential = config: path: let
    matches = builtins.filter (secret: secret.path == path) (builtins.attrValues config.sops.secrets);
  in
    assert lib.assertMsg (path != null && builtins.length matches == 1) "telemetry rotation needs an explicit node-owned SOPS credential for ${toString path}";
      target (builtins.head matches);
  instance = cluster.activeServices.observability or null;
  receiverConfig = nixosConfigurations.${instance.host}.config;
  ingress = receiverConfig.laplace.services.observability.ingress;
  admitted = lib.filterAttrs (name: _: name != instance.host) instance.settings.writers;
  writers = lib.mapAttrs (name: writer: let
    config = nixosConfigurations.${name}.config;
    identity = config.laplace.services.telemetry.clientIdentity;
    certificate = receiverConfig.sops.secrets.${writer.certificateSecret};
    receiverCertificate = target certificate;
    declaredSource = sourceFile (
      if writer.sopsFile == null
      then instance.settings.sopsFile
      else writer.sopsFile
    );
  in
    assert lib.assertMsg (cluster.hosts.${name}.telemetry or false) "telemetry rotation writer ${name} is not an enabled telemetry node";
    assert lib.assertMsg (ingress.writers.${name}.certificateFile == certificate.path && receiverCertificate.file == declaredSource) "telemetry rotation writer ${name} disagrees with its declared receiver certificate mapping"; {
      clientCertificate = credential config identity.certificateFile;
      clientKey = credential config identity.keyFile;
      inherit receiverCertificate;
    })
  admitted;
  receiver = {
    host = instance.host;
    ca = credential receiverConfig ingress.caFile;
  };
  caBundle = {
    file = sourceFile (sourceDirectory + "/telemetry-ca.yaml");
    keyPath = "[\"data\"]";
  };
  targets = [receiver.ca caBundle] ++ lib.concatMap (writer: [writer.clientCertificate writer.clientKey writer.receiverCertificate]) (builtins.attrValues writers);
  destinations = map builtins.toJSON targets;
in
  assert lib.assertMsg (instance != null) "telemetry rotation needs an active observability receiver";
  assert lib.assertMsg (builtins.all (name: builtins.match "[a-z0-9][a-z0-9-]*" name != null) (builtins.attrNames admitted)) "telemetry rotation writer identities must be lowercase host names";
  assert lib.assertMsg (ingress.enable && builtins.attrNames ingress.writers == builtins.attrNames admitted) "telemetry rotation requires the receiver's actual admission set to match the manifest";
  assert lib.assertMsg (writers != {}) "telemetry rotation needs at least one explicitly admitted remote writer";
  assert lib.assertMsg (builtins.length destinations == builtins.length (lib.unique destinations)) "telemetry rotation destinations must not overwrite another identity or key"; {
    inherit receiver caBundle writers;
    files = lib.sort builtins.lessThan (lib.unique (map (entry: entry.file) targets));
  }
