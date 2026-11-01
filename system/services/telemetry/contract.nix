{lib}: let
  domain = "telemetry.dysthesis.com";
  metricsPort = 8443;
  journalPort = 8444;
  defaultMetricsOrigin = "https://${domain}:${toString metricsPort}";
  defaultJournalOrigin = "https://${domain}:${toString journalPort}";
  # Make sure that origins contain only the scheme and authority before URL construction.
  # The hostname, IPv6 and port syntax can still be incorrect.
  # The code does not normalise full-URL overrides.
  validOrigin = origin:
    builtins.isString origin && builtins.match "https?://([A-Za-z0-9.-]+|[[][0-9A-Fa-f:.]+[]])(:[0-9]+)?" origin != null;
in {
  inherit domain metricsPort journalPort;
  listenAddress = "127.0.0.1";
  nodeExporterPort = 9100;
  vmagentPort = 8429;
  metricsOrigin = defaultMetricsOrigin;
  journalOrigin = defaultJournalOrigin;
  endpoints = {
    writer,
    metricsOrigin ? defaultMetricsOrigin,
    journalOrigin ? defaultJournalOrigin,
  }: let
    metricsPath = "/${writer}/metrics";
    journalBasePath = "/${writer}/journald";
  in
    assert lib.assertMsg (builtins.isString writer && builtins.match "[a-z0-9][a-z0-9-]*" writer != null) "telemetry writer must be a lowercase host-style path segment"; {
      inherit metricsPath journalBasePath;
      journalUploadPath = "${journalBasePath}/upload";
      metricsUrl = assert lib.assertMsg (validOrigin metricsOrigin) "telemetry metrics origin must be an http(s) scheme and authority without a trailing slash, path, query, or fragment"; "${metricsOrigin}${metricsPath}";
      journalBaseUrl = assert lib.assertMsg (validOrigin journalOrigin) "telemetry journal origin must be an http(s) scheme and authority without a trailing slash, path, query, or fragment"; "${journalOrigin}${journalBasePath}";
    };
}
