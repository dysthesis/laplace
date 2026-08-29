final: prev: {
  fast-fonts = final.callPackage ./fast-fonts {};
  sf-pro = final.callPackage ./sf-pro {};
  georgia-fonts = final.callPackage ./georgia-fonts {};
  jbcustom-nf = final.callPackage ./jbcustom-nf {};
  literata = final.callPackage ./literata {};

  karakeep = prev.karakeep.overrideAttrs (oldAttrs: let
    patches = oldAttrs.patches ++ [./karakeep-better-sqlite3.patch];
  in {
    inherit patches;

    pnpmDeps = final.fetchPnpmDeps {
      inherit (oldAttrs) pname version;
      pnpm = final.pnpm_9;
      src = final.stdenv.mkDerivation {
        name = "${oldAttrs.pname}-patched-source";
        inherit (oldAttrs) src;
        inherit patches;
        installPhase = ''
          cp -pr --reflink=auto -- . $out
        '';
      };
      fetcherVersion = 3;
      hash = "sha256-bBNwo0Zgmb3pvuxsfDur2HDtNRMS8VKGbNNBpZ6XX2I=";
    };

    preBuild =
      (oldAttrs.preBuild or "")
      + ''
        rm -rf node_modules/better-sqlite3/prebuilds
      '';

    postInstallCheck =
      (oldAttrs.postInstallCheck or "")
      + ''
        addon="$out/lib/karakeep/node_modules/better-sqlite3"
        test ! -e "$addon/prebuilds"
        test -e "$addon/build/Release/better_sqlite3.node"
        ${final.lib.getExe final.nodejs} - "$addon" <<'EOF'
        const addonPath = process.argv[2];
        const metadata = require(addonPath + "/package.json");
        if (metadata.version !== "13.0.3") {
          throw new Error("expected better-sqlite3 13.0.3, got " + metadata.version);
        }

        const Database = require(addonPath);
        const db = new Database(":memory:");
        let junk = [];
        for (let i = 0; i < 300000; i += 1) {
          db.prepare("SELECT ?").get(i);
          junk.push({ value: i });
          if (junk.length > 1000) junk = [];
        }
        db.close();
        console.log("better-sqlite3 13.0.3 allocation GC probe passed");
        EOF
      '';
  });

  # Curried: `pkgs.proxmox-vma { rawImage; qemuConf; baseName; }`. Consumed by
  # the proxmox guest profile to turn a disko raw image into a VMA archive.
  proxmox-vma = final.callPackage ./proxmox-vma {};
}
