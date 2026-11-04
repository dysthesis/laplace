{
  stdenvNoCC,
  fetchFromGitHub,
  python3,
  python3Packages,
  hyprcursor,
}: let
  themeName = "Bibata-Modern-Classic-Hyprcursor";
in
  stdenvNoCC.mkDerivation (final: {
    pname = "bibata-hyprcursor";
    version = "v2.0.7";

    src = fetchFromGitHub {
      owner = "ful1e5";
      repo = "Bibata_Cursor";
      rev = final.version;
      hash = "sha256-kIKidw1vditpuxO1gVuZeUPdWBzkiksO/q2R/+DUdEc=";
    };

    nativeBuildInputs = [
      python3
      python3Packages.tomli
      python3Packages.tomli-w
      hyprcursor
    ];

    phases = [
      "unpackPhase"
      "configurePhase"
      "buildPhase"
      "installPhase"
    ];

    unpackPhase = ''
      runHook preUnpack

      cp $src/configs/normal/x.build.toml config.toml

      mkdir cursors
      for cursor in $src/svg/modern/*; do
        cp -r $src/svg/modern/$(readlink $cursor) cursors
      done

      chmod -R u+w .

      runHook postUnpack
    '';

    configurePhase = ''
      runHook preConfigure

      cat << EOF > manifest.hl
      name = ${themeName}
      description = The Bibata Cursor theme packaged for hyprcursor.
      version = ${final.version}
      cursors_directory = cursors
      EOF

      find cursors -type f -name '*.svg' | xargs sed -i -e 's/#00FF00/#000000/g' -e 's/#0000FF/#FFFFFF/g' -e 's/#FF0000/#000000/g'

      python ${./configure.py} config.toml cursors

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      hyprcursor-util --create . --output .
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/icons
      cp -r theme_${themeName} $out/share/icons/${themeName}

      runHook postInstall
    '';
  })
