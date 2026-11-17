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
    source = "${inputs.retirement.outPath}/packwiz";
    site = serviceFixtures.minecraft.services.caddy.virtualHosts."mc.example.test".extraConfig;
    endpoints = serviceFixtures.cluster.manifest.endpoints.minecraft;
  in
    assert endpoints.https.port == 443 && endpoints.https.scope == "tailnet";
    assert endpoints.https.publishDNS && !endpoints.game.publishDNS;
    assert lib.hasInfix "handle_path /modpack/*" site;
    assert lib.hasInfix "root * ${source}" site;
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

  minecraft-bootstrap = let
    bootstrap = import ../../system/services/minecraft/bootstrap.nix {
      inherit pkgs lib inputs;
      domain = "mc.example.test";
      port = 25565;
    };
    site = serviceFixtures.minecraft.services.caddy.virtualHosts."mc.example.test".extraConfig;
  in
    assert lib.hasInfix "handle /bootstrap/RetirementHome-bootstrap.zip" site;
      pkgs.runCommand "minecraft-bootstrap-check" {nativeBuildInputs = [pkgs.python3];} ''
        python3 - ${bootstrap}/RetirementHome-bootstrap.zip ${inputs.retirement.outPath}/packwiz/pack.toml <<'PYTHON'
        import io
        import json
        import struct
        import sys
        import tomllib
        import zipfile
        from pathlib import Path

        pack = tomllib.loads(Path(sys.argv[2]).read_text())
        with zipfile.ZipFile(sys.argv[1]) as archive:
            names = set(archive.namelist())
            assert {"instance.cfg", "mmc-pack.json", "minecraft/servers.dat", "minecraft/packwiz-installer-bootstrap.jar"} <= names
            components = json.loads(archive.read("mmc-pack.json"))["components"]
            assert [(c["uid"], c["version"]) for c in components] == [
                ("net.minecraft", pack["versions"]["minecraft"]),
                ("net.neoforged", pack["versions"]["neoforge"]),
            ]
            cfg = archive.read("instance.cfg").decode()
            assert "-s client https://mc.example.test/modpack/pack.toml" in cfg
            assert "OverrideJavaArgs=true" in cfg and "OverrideMemory=true" in cfg
            assert "MaxMemAlloc=6144" in cfg and "MinMemAlloc=1024" in cfg
            assert "JvmArgs=-XX:+UseG1GC" in cfg
            # Verify the embedded JAR is a nonempty ZIP archive.
            with zipfile.ZipFile(io.BytesIO(archive.read("minecraft/packwiz-installer-bootstrap.jar"))) as jar:
                assert jar.namelist()
            data = io.BytesIO(archive.read("minecraft/servers.dat"))
            def utf():
                length = struct.unpack(">H", data.read(2))[0]
                return data.read(length).decode("utf-8")
            assert data.read(1) == b"\x0a" and utf() == ""
            assert data.read(1) == b"\x09" and utf() == "servers"
            assert data.read(1) == b"\x0a" and struct.unpack(">i", data.read(4))[0] == 1
            assert data.read(1) == b"\x08" and utf() == "name" and utf() == "Retirement Home"
            assert data.read(1) == b"\x08" and utf() == "ip" and utf() == "mc.example.test"
            assert data.read() == b"\x00\x00"
        PYTHON
        touch "$out"
      '';

  minecraft-config-staging = import ./minecraft-config-staging.nix {
    inherit pkgs inputs;
  };
}
