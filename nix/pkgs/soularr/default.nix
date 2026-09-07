{
  fetchFromGitHub,
  fetchurl,
  lib,
  makeWrapper,
  python3,
  python3Packages,
  stdenvNoCC,
}: let
  slskd-api = python3Packages.buildPythonPackage rec {
    pname = "slskd-api";
    version = "0.1.5";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/83/d8/4f06e30ca269ce08076fa42b62727a6c6c8983b28aa9028e51221eeb92a0/slskd_api-${version}-py3-none-any.whl";
      hash = "sha256-3gPCGgtfK2MW+NvycMaFkIW/VS6B7WAkqxkvUdRWpMA=";
    };

    dependencies = [python3Packages.requests];
    pythonImportsCheck = ["slskd_api"];
  };

  python = python3.withPackages (ps: [
    ps.music-tag
    ps.pyarr
    slskd-api
  ]);
in
  stdenvNoCC.mkDerivation rec {
    pname = "soularr";
    version = "1.2.2";

    src = fetchFromGitHub {
      owner = "mrusse";
      repo = "soularr";
      tag = "v${version}";
      hash = "sha256-gtz99+DiFjJZuq54qo5C+5Exx++S+ePzldgDM9NHAOA=";
    };

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      install -Dm755 soularr.py "$out/libexec/soularr/soularr.py"
      makeWrapper ${python}/bin/python "$out/bin/soularr" \
        --add-flags "-u $out/libexec/soularr/soularr.py"

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      "$out/bin/soularr" --help >/dev/null
    '';

    meta = {
      description = "Connects Lidarr wanted albums to Soulseek through slskd";
      homepage = "https://github.com/mrusse/soularr";
      changelog = "https://github.com/mrusse/soularr/releases/tag/v${version}";
      license = lib.licenses.gpl3Only;
      mainProgram = "soularr";
      platforms = lib.platforms.linux;
    };
  }
