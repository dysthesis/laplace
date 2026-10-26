{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.minecraft.retirement-home;
  packwizTemplate = builtins.path {
    path = ./packwiz;
    name = "retirement-home-packwiz-template";
  };
  # PackWiz verifies both the file and index hashes. Render the client-side
  # signing exception with the selected endpoint and update both hash links.
  preferencesPath = "config/NoChatReports/NCR-ServerPreferences.json";
  preferences =
    builtins.toJSON {
      signingModes."${cfg.domain}:${toString cfg.port}" = "NEVER";
    }
    + "\n";
  sourceIndex = builtins.readFile ./packwiz/index.toml;
  indexedPreferences =
    lib.findFirst (file: file.file == preferencesPath)
    (throw "PackWiz index is missing ${preferencesPath}")
    (builtins.fromTOML sourceIndex).files;
  index =
    lib.replaceStrings [indexedPreferences.hash]
    [(builtins.hashString "sha256" preferences)]
    sourceIndex;
  sourcePack = builtins.readFile ./packwiz/pack.toml;
  pack =
    lib.replaceStrings [(builtins.fromTOML sourcePack).index.hash]
    [(builtins.hashString "sha256" index)]
    sourcePack;
  packwizSource = pkgs.runCommand "retirement-home-packwiz" {} ''
    cp -r ${packwizTemplate} "$out"
    chmod u+w "$out" "$out/config" "$out/config/NoChatReports"
    rm "$out/${preferencesPath}" "$out/index.toml" "$out/pack.toml"
    cp ${pkgs.writeText "NCR-ServerPreferences.json" preferences} "$out/${preferencesPath}"
    cp ${pkgs.writeText "index.toml" index} "$out/index.toml"
    cp ${pkgs.writeText "pack.toml" pack} "$out/pack.toml"
  '';
  packwizUrl = "https://${cfg.domain}/packwiz/pack.toml";
  packwizBootstrapJar = pkgs.fetchurl {
    url = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar";
    hash = "sha256-qPuyTcYEJ46X9GiOgtPZGjGLmO/AjV2/y8vKtkQ9EWw=";
  };
  packwizIcon = ./retirement-home.png;
  packwizBootstrap =
    pkgs.runCommand "retirement-home-packwiz-bootstrap" {
      nativeBuildInputs = [pkgs.zip];
      minecraftServerAddress = cfg.domain + lib.optionalString (cfg.port != 25565) ":${toString cfg.port}";
    } ''
      mkdir -p work/minecraft "$out"
      cp ${packwizBootstrapJar} work/minecraft/packwiz-installer-bootstrap.jar
      cp ${packwizIcon} work/retirement-home.png
      # Pre-seed the selected game's published endpoint without fixed NBT lengths.
      {
        printf '\x0a\x00\x00\x09\x00\x07servers\x0a\x00\x00\x00\x01\x08\x00\x04name\x00\x0fRetirement Home\x08\x00\x02ip'
        printf '%b' "$(printf '\\x%02x\\x%02x' "$(( ''${#minecraftServerAddress} / 256 ))" "$(( ''${#minecraftServerAddress} % 256 ))")"
        printf '%s\x00\x00' "$minecraftServerAddress"
      } > work/minecraft/servers.dat
      cat > work/instance.cfg <<'EOF'
      [General]
      ConfigVersion=1.3
      ExportAuthor=dysthesis
      ExportName=Retirement Home
      ExportSummary=Custom modpack built on Fabulously Optimized, built for a private server.
      ExportVersion=1.0.0
      InstanceType=OneSix
      ManagedPack=false
      ManagedPackID=
      ManagedPackName=
      ManagedPackType=
      ManagedPackURL=
      ManagedPackVersionID=
      ManagedPackVersionName=
      MaxMemAlloc=5120
      MinMemAlloc=2048
      OverrideCommands=true
      OverrideMemory=true
      PreLaunchCommand=\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar -g ${packwizUrl}
      iconKey=retirement-home
      name=Retirement Home

      [UI]
      EOF
      cat > work/mmc-pack.json <<'EOF'
      {
        "components": [
          { "uid": "net.minecraft", "version": "1.20.1" },
          { "uid": "net.fabricmc.fabric-loader", "version": "0.18.4" }
        ],
        "formatVersion": 1
      }
      EOF
      (cd work && zip -qr "$out/RetirementHome-bootstrap.zip" instance.cfg mmc-pack.json minecraft/packwiz-installer-bootstrap.jar minecraft/servers.dat retirement-home.png)
    '';
in {
  config = lib.mkIf cfg.enable {
    laplace.services.caddy = {
      enable = true;
      cloudflare.proxies.${cfg.mapDomain} = "localhost:8080";
      virtualHosts.${cfg.domain}.extraConfig = ''
        tls {
          dns cloudflare {env.CF_API_TOKEN}
          resolvers 1.1.1.1
        }
        @notSSE not header Accept *text/event-stream*
        encode @notSSE
        route /packwiz/* {
          root * ${packwizSource}
          uri strip_prefix /packwiz
          file_server
        }
        route /bootstrap/RetirementHome-bootstrap.zip {
          root * ${packwizBootstrap}
          rewrite * /RetirementHome-bootstrap.zip
          header Content-Disposition "attachment; filename=RetirementHome-bootstrap.zip"
          file_server
        }
      '';
    };
  };
}
