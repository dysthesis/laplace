{
  fetchFromGitHub,
  lib,
  python3Packages,
  rustPlatform,
  ...
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "headroom-ai";
  version = "0.39.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "headroomlabs-ai";
    repo = "headroom";
    tag = "v${finalAttrs.version}";
    hash = "sha256-pcsKKq27cKyB7uWskbnWP8VI/UU9RdrE89QClLisvcU=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-azHjTfjdARzYuDMdH1AOYn0YV9U9lzaoULcSC/a9MuE=";
  };

  postPatch = ''
    substituteInPlace headroom/ccr/mcp_server.py \
      --replace-fail \
        "return HeadroomMCPServer(proxy_url=proxy_url)" \
        'return HeadroomMCPServer(proxy_url=proxy_url, check_proxy=os.environ.get("HEADROOM_MCP_CHECK_PROXY", "1").lower() not in ("0", "false", "off"))'

    substituteInPlace headroom/cli/wrap.py \
      --replace-fail \
        'cmd = [sys.executable, "-m", "headroom.cli", "proxy", "--port", str(port)]' \
        "cmd = [\"$out/bin/headroom\", \"proxy\", \"--port\", str(port)]"

    # Disable Headroom's external beacon and local telemetry at the
    # implementation boundary. Environment variables cannot re-enable them.
    cat > headroom/telemetry/beacon.py <<'PY'
    """Telemetry disabled by downstream packaging."""

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
    # Core.
    ast-grep-cli
    click
    litellm
    opentelemetry-api
    pydantic
    pyyaml
    rich
    tiktoken
    tomlkit

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
    # Defence in depth. The source patch above already makes the Headroom
    # beacon and local telemetry impossible to enable.
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

    # Headroom otherwise re-execs the bare Python interpreter to apply
    # malloc tuning. That has the same Nix environment problem as wrap.
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
  ];

  meta = {
    description = "Local context compression tools for LLM applications";
    homepage = "https://github.com/headroomlabs-ai/headroom";
    license = lib.licenses.asl20;
    mainProgram = "headroom";
  };
})
