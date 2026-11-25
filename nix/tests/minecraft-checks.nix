{
  pkgs,
  lib,
  inputs,
  serviceFixtures,
}: {
  minecraft-maintenance = let
    services = serviceFixtures.minecraft.systemd.services;
    snapshot = pkgs.writeText "mc-world-snapshot.sh" services.mc-world-snapshot.script;
    restart = pkgs.writeText "mc-nightly-restart.sh" services.mc-nightly-restart.script;
  in
    pkgs.runCommand "minecraft-maintenance-check" {nativeBuildInputs = [pkgs.bash];} ''
      bash -n ${snapshot}
      bash -n ${restart}
      touch $out
    '';

  minecraft-runtime = let
    runtime = pkgs.jdk25_headless;
    server = serviceFixtures.minecraft.services.minecraft-servers.servers.retirement-home;
  in
    assert server.enable;
    assert lib.versionAtLeast runtime.version "25";
      pkgs.runCommand "minecraft-runtime-check" {} ''
        ${runtime}/bin/java -Xms128M -Xmx256M -version >java-version 2>&1
        grep -Eq 'version "25[."]' java-version
        touch $out
      '';

  # Serve the raw Packwiz tree. The assembled modpack-client output has JARs
  # and packwiz.json, but does not contain the indexed .pw.toml manifests.
  minecraft-packwiz-hosting = let
    source = inputs.retirement.packages.${pkgs.stdenv.hostPlatform.system}.packwiz-source;
    # lib.hasInfix rejects patterns that carry store-path context.
    site = builtins.unsafeDiscardStringContext serviceFixtures.minecraft.services.caddy.virtualHosts."mc.example.test".extraConfig;
    endpoints = serviceFixtures.cluster.manifest.endpoints.minecraft;
  in
    assert endpoints.https.port == 443 && endpoints.https.scope == "tailnet";
    assert endpoints.https.publishDNS && !endpoints.game.publishDNS;
    assert lib.hasInfix "handle_path /modpack/*" site;
    assert lib.hasInfix "root * ${builtins.unsafeDiscardStringContext "${source}"}" site;
    assert lib.hasInfix "handle /bootstrap/RetirementHome-bootstrap.zip" site;
      pkgs.runCommand "minecraft-packwiz-hosting-check" {nativeBuildInputs = [pkgs.python3];} ''
        python3 - ${lib.escapeShellArg source} <<'PYTHON'
        import hashlib
        import sys
        import tomllib
        from pathlib import Path

        root = Path(sys.argv[1])
        pack = tomllib.loads((root / "pack.toml").read_text())
        index_spec = pack["index"]
        index_path = root / index_spec["file"]
        index_data = index_path.read_bytes()
        assert hashlib.new(index_spec["hash-format"], index_data).hexdigest() == index_spec["hash"].lower()
        index = tomllib.loads(index_data.decode())
        for entry in index["files"]:
            name = Path(entry["file"])
            assert not name.is_absolute() and ".." not in name.parts
            data = (root / name).read_bytes()
            algorithm = entry.get("hash-format", index["hash-format"])
            assert hashlib.new(algorithm, data).hexdigest() == entry["hash"].lower(), name
        PYTHON
        touch "$out"
      '';
}
