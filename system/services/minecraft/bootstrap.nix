# A Prism Launcher import ZIP for the pinned Retirement pack.
# Keep the Packwiz tree and the loader versions in the same flake revision.
{
  inputs,
  lib,
  pkgs,
  domain,
  port,
}: let
  pack = builtins.fromTOML (builtins.readFile "${inputs.retirement.outPath}/packwiz/pack.toml");
  address = domain + lib.optionalString (port != 25565) ":${toString port}";
  components = pkgs.writeText "retirement-home-mmc-pack.json" (builtins.toJSON {
    formatVersion = 1;
    components = [
      {
        uid = "net.minecraft";
        version = pack.versions.minecraft;
      }
      {
        uid = "net.neoforged";
        version = pack.versions.neoforge;
      }
    ];
  });
  installer = pkgs.fetchurl {
    # Pin the asset URL as well as its content hash.
    url = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar";
    hash = "sha256-qPuyTcYEJ46X9GiOgtPZGjGLmO/AjV2/y8vKtkQ9EWw=";
  };
in
  pkgs.runCommand "retirement-home-bootstrap" {
    nativeBuildInputs = [pkgs.python3 pkgs.zip];
    serverAddress = address;
  } ''
    mkdir -p work/minecraft "$out"
    cp ${installer} work/minecraft/packwiz-installer-bootstrap.jar
    cp ${components} work/mmc-pack.json

    # Prism Launcher reads these as instance-specific JVM and memory settings.
    cat > work/instance.cfg <<'EOF'
    [General]
    ConfigVersion=1.3
    ExportAuthor=dysthesis
    ExportName=Retirement Home
    ExportSummary=Retirement NeoForge modpack
    ExportVersion=${pack.version}
    InstanceType=OneSix
    ManagedPack=false
    MaxMemAlloc=6144
    MinMemAlloc=1024
    OverrideCommands=true
    OverrideJavaArgs=true
    OverrideMemory=true
    JvmArgs=-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200
    PreLaunchCommand=\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar -g -s client https://${domain}/modpack/pack.toml
    name=Retirement Home

    [UI]
    EOF

    # Minecraft servers.dat is a big-endian, named binary tag (NBT) compound.
    python3 - <<'PYTHON'
    import os
    import struct
    from pathlib import Path

    def utf(value):
        encoded = value.encode("utf-8")
        assert len(encoded) <= 65535
        return struct.pack(">H", len(encoded)) + encoded

    data = b"\x0a" + utf("")  # Root TAG_Compound
    data += b"\x09" + utf("servers")  # TAG_List
    data += b"\x0a" + struct.pack(">i", 1)  # One TAG_Compound
    data += b"\x08" + utf("name") + utf("Retirement Home")
    data += b"\x08" + utf("ip") + utf(os.environ["serverAddress"])
    data += b"\x00\x00"  # End server and root compounds
    Path("work/minecraft/servers.dat").write_bytes(data)
    PYTHON

    cat > work/README.txt <<'EOF'
    Retirement Home - Minecraft ${pack.versions.minecraft}, NeoForge ${pack.versions.neoforge}

    Import RetirementHome-bootstrap.zip using Prism Launcher -> Add Instance -> Import.
    Configure Java 25 under Edit Instance -> Settings -> Java before launch.
    The instance uses a 6 GiB maximum Java heap. Increase it only if needed.
    Join ${address} over the private Tailnet.
    The pre-launch updater downloads the client pack from:
    https://${domain}/modpack/pack.toml
    EOF

    (cd work && zip -qr "$out/RetirementHome-bootstrap.zip" \
      instance.cfg mmc-pack.json README.txt \
      minecraft/packwiz-installer-bootstrap.jar minecraft/servers.dat)
  ''
