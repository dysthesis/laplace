{
  python314,
  fetchFromGitHub,
  rustPlatform,
  makeWrapper,
  pkg-config,
  onnxruntime,
  openssl,
  lib,
  ast-grep,
  ...
}: let
  pyPkgs = python314.pkgs;
in
  pyPkgs.buildPythonApplication rec {
    pname = "headroom-ai";
    version = "0.32.0";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "headroomlabs-ai";
      repo = "headroom";
      tag = "v${version}";
      hash = "sha256-7+ul+rco4HvI3ar6Y9JvfBiFem8IeBwnBEGUcj/d9xU=";
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit pname version src;
      hash = "sha256-bSBtv1CUP2NjZujQSsAgPpeFYd28O5Ea1FXKu6ZRcvs=";
    };

    nativeBuildInputs = [
      makeWrapper
      pkg-config
      rustPlatform.cargoSetupHook
      rustPlatform.maturinBuildHook
    ];

    buildInputs = [
      onnxruntime
      openssl
    ];

    postPatch = ''
      substituteInPlace headroom/proxy/models.py \
        --replace-fail 'from dataclasses import InitVar, dataclass, field' $'from dataclasses import InitVar, dataclass, field\nimport os' \
        --replace-fail 'from headroom.providers.registry import ProviderApiOverrides' $'from headroom.providers.registry import ProviderApiOverrides\n\n\ndef _env_int_or_none(name: str) -> int | None:\n    raw = os.environ.get(name, "").strip()\n    if not raw:\n        return None\n    try:\n        return int(raw)\n    except ValueError:\n        return None' \
        --replace-fail 'compression_max_workers: int | None = None' 'compression_max_workers: int | None = field(default_factory=lambda: _env_int_or_none("HEADROOM_COMPRESSION_MAX_WORKERS"))'
    '';

    env = {
      ORT_STRATEGY = "system";
      ORT_LIB_LOCATION = "${lib.getLib onnxruntime}/lib";
      ORT_PREFER_DYNAMIC_LINK = "true";
      ORT_DYLIB_PATH = "${lib.getLib onnxruntime}/lib/libonnxruntime.so";
    };

    dependencies = with pyPkgs; [
      tomlkit
      click
      fastapi
      h2
      httpx
      litellm
      magika
      mcp
      openai
      pydantic
      rich
      sqlite-vec
      tiktoken
      transformers
      uvicorn
      watchdog
      websockets
      zstandard
      opentelemetry-api
      onnxruntime
    ];

    pythonRelaxDeps = [
      "litellm"
    ];

    pythonRemoveDeps = [
      "ast-grep-cli"
    ];

    makeWrapperArgs = [
      "--prefix PATH : ${lib.makeBinPath [ast-grep]}"
      "--set ORT_DYLIB_PATH ${lib.getLib onnxruntime}/lib/libonnxruntime.so"
      "--prefix LD_LIBRARY_PATH : ${lib.getLib onnxruntime}/lib"
    ];

    pythonImportsCheck = [
      "headroom"
    ];

    meta = {
      description = "Context optimization layer for LLM applications and coding agents";
      homepage = "https://github.com/chopratejas/headroom";
      changelog = "https://github.com/chopratejas/headroom/releases/tag/v${version}";
      license = lib.licenses.asl20;
      mainProgram = "headroom";
      platforms = lib.platforms.linux;
    };
  }
