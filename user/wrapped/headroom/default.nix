{
  fetchFromGitHub,
  lib,
  oniguruma,
  pkg-config,
  python3Packages,
  rustPlatform,
  sqlite,
  ...
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "headroom-ai";
  version = "0.44.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "headroomlabs-ai";
    repo = "headroom";
    tag = "v${finalAttrs.version}";
    hash = "sha256-t3hBnXKRzzMOFPFTyFu6+uV0QVGKJH4ZjIXQVG/4I5U=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-hhfYzkv7N/7L1Gv9I9RcnLRsrTjcRkBroo5ei5VbuHU=";
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

  nativeBuildInputs = [pkg-config];
  buildInputs = [oniguruma sqlite];

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

    # These dependencies provide headroom-ai[proxy].
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
    "headroom._core"
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
