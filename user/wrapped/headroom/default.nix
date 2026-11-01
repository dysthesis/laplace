{
  fetchFromGitHub,
  lib,
  python3Packages,
  rustPlatform,
  ...
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "headroom-ai";
  version = "0.41.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "headroomlabs-ai";
    repo = "headroom";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ITVrw5ruGnNI9t7pq+0Z6gsnqDDAB/5v7I3oOQM5AtE=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-RF1b24TIV3EASGfXKUHSrGgQGBUmJLYxzDEjb4fvKPo=";
  };

  postPatch = ''
    substituteInPlace headroom/ccr/mcp_server.py \
      --replace-fail \
        "return HeadroomMCPServer(proxy_url=proxy_url)" \
        'return HeadroomMCPServer(proxy_url=proxy_url, check_proxy=os.environ.get("HEADROOM_MCP_CHECK_PROXY", "1").lower() not in ("0", "false", "off"))'

    # Disable the external beacon and local telemetry in the source so environment variables cannot enable them.
    cat > headroom/telemetry/beacon.py <<'PY'

    BEACON_DEFAULT_ON = False


    def is_telemetry_enabled() -> bool:
        return False


    def is_beacon_enabled() -> bool:
        return False


    def is_telemetry_warn_enabled() -> bool:
        return False


    def format_telemetry_notice(*, prefix: str = "") -> str:
        return ""
    PY
  '';

  build-system = with rustPlatform; [
    cargoSetupHook
    maturinBuildHook
  ];

  dependencies = with python3Packages; [
    ast-grep-cli
    click
    litellm
    opentelemetry-api
    pydantic
    pyyaml
    rich
    tiktoken
    tomlkit

    truststore

    # headroom-ai[proxy].
    fastapi
    h2
    httpx
    magika
    mcp
    onnxruntime
    openai
    orjson
    sqlite-vec
    starlette
    transformers
    uvicorn
    watchdog
    websockets
    zstandard
  ];

  makeWrapperArgs = [
    "--set"
    "HEADROOM_TELEMETRY"
    "off"

    "--set"
    "HEADROOM_BEACON"
    "off"

    "--set"
    "HEADROOM_OTEL_METRICS_ENABLED"
    "0"

    "--set"
    "HEADROOM_LANGFUSE_ENABLED"
    "0"

    "--set"
    "DO_NOT_TRACK"
    "1"

    # Malloc tuning restarts the bare Python interpreter, which cannot use the wrapped Nix environment.
    "--set"
    "HEADROOM_MALLOC_TUNING"
    "0"
  ];

  pythonImportsCheck = [
    "headroom"
    "fastapi"
    "httpx"
    "magika"
    "mcp"
    "onnxruntime"
    "openai"
    "orjson"
    "transformers"
    "uvicorn"
    "watchdog"
    "websockets"
    "zstandard"
    "truststore"
  ];

  meta = {
    description = "Local context compression tools for LLM applications";
    homepage = "https://github.com/headroomlabs-ai/headroom";
    license = lib.licenses.asl20;
    mainProgram = "headroom";
  };
})
