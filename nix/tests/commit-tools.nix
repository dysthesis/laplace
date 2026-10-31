{
  lib,
  pkgs,
}:
pkgs.runCommand "commit-tools-check" {nativeBuildInputs = [pkgs.git pkgs.python3];} ''
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  python3 - <<'PY'
  import json
  from http.server import BaseHTTPRequestHandler, HTTPServer
  from pathlib import Path
  import subprocess
  import threading

  subject = """fix: preserve "quotes" and don't evaluate $(touch injected)"""
  subprocess.run(["git", "init", "-q", "repository"], check=True)
  repository = Path("repository")
  (repository / "fixture").write_text(subject + "\n")
  subprocess.run(["git", "add", "fixture"], cwd=repository, check=True)
  diff = subprocess.check_output(
      ["git", "diff", "--cached", "--no-color", "-U0"], cwd=repository, text=True
  ).rstrip("\n")
  requests = []

  class Handler(BaseHTTPRequestHandler):
      def do_POST(self):
          requests.append(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
          response = json.dumps({
              "message": {"content": json.dumps({"suggestions": [subject]})}
          }).encode()
          self.send_response(200)
          self.send_header("Content-Type", "application/json")
          self.send_header("Content-Length", str(len(response)))
          self.end_headers()
          self.wfile.write(response)

      def log_message(self, *args):
          pass

  server = HTTPServer(("127.0.0.1", 11434), Handler)
  worker = threading.Thread(target=server.serve_forever, daemon=True)
  worker.start()
  try:
      result = subprocess.run(
          ["${lib.getExe pkgs.scripts.generate-commit}", "--list"],
          cwd=repository, check=True, capture_output=True, text=True, timeout=15,
      )
      assert result.stdout == subject + "\n", result
      assert len(requests) == 1, requests
      assert requests[0]["messages"][1]["content"].endswith("\n\n" + diff), requests
  finally:
      server.shutdown()
      server.server_close()
      worker.join()
  PY
  touch "$out"
''
