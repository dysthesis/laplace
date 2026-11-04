import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock


HERE = Path(__file__).resolve().parent


def load_module(filename):
    spec = importlib.util.spec_from_file_location(filename.stem, filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


probe = load_module(HERE / "pty-probe.py")
stats = load_module(HERE / "stats.py")


class OutputTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = str(Path(self.tmp.name) / "samples.json")
        Path(self.path).write_text(json.dumps({
            "label": "sample", "mode": "isolated", "spawn_mode": "interactive",
            "samples": {"first_prompt_lag_ms": [1.0, None, 3.0]},
        }))

    def test_stats_text_and_json_keep_metrics(self):
        for as_json in (False, True):
            with self.subTest(as_json=as_json):
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    stats.cmd_summarize([self.path], as_json)
                if as_json:
                    metric = json.loads(output.getvalue())[0]["metrics"]["first_prompt_lag_ms"]
                    self.assertEqual(metric["n"], 2)
                    self.assertEqual(metric["median"], 2.0)
                else:
                    self.assertIn("sample", output.getvalue())
                    self.assertIn("first_prompt_lag_ms", output.getvalue())

                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    stats.cmd_compare(self.path, self.path, as_json)
                if as_json:
                    row = json.loads(output.getvalue())["rows"][0]
                    self.assertEqual(row["metric"], "first_prompt_lag_ms")
                    self.assertEqual(row["delta_ms"], 0.0)
                    self.assertFalse(row["significant"])
                else:
                    self.assertIn("baseline: sample", output.getvalue())
                    self.assertIn("first_prompt_lag_ms", output.getvalue())

    def test_collect_keeps_group_selection_and_stdout_clean(self):
        with (
            mock.patch.object(probe, "measure_spawn_metrics", return_value={"first_prompt_lag_ms": [1.0]}) as spawn,
            mock.patch.object(probe, "measure_first_command", return_value=[2.0]) as command,
            mock.patch.object(probe, "measure_exit_time", return_value=[3.0]) as exit_time,
        ):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                result = probe.collect(None, {}, set())
            self.assertEqual(result, {
                "first_prompt_lag_ms": [1.0],
                "first_command_lag_ms": [2.0],
                "exit_time_ms": [3.0],
            })
            self.assertEqual(output.getvalue(), "")
            for measurement in (spawn, command, exit_time):
                measurement.assert_called_once_with(None, {})
                measurement.reset_mock()
            self.assertEqual(probe.collect(None, {}, {"spawn", "first_command", "exit"}), {})
            for measurement in (spawn, command, exit_time):
                measurement.assert_not_called()


class CliTests(unittest.TestCase):
    def test_dry_run_needs_no_tools_and_writes_no_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            for args in ([], ["--ab", "/missing/fish-A", "/missing/fish-B"]):
                with self.subTest(args=args):
                    out = Path(tmp) / "results"
                    result = subprocess.run(
                        [shutil.which("bash"), str(HERE / "shell-bench.sh"),
                         "--dry-run", "--out", str(out), *args],
                        env={"PATH": tmp, "BENCH_LIB": str(HERE)},
                        capture_output=True, text=True, timeout=5,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, "")
                    self.assertIn("no builds, measurements or output files", result.stderr)
                    self.assertFalse(out.exists())
                    if args:
                        self.assertIn("/missing/fish-A vs /missing/fish-B", result.stderr)


if __name__ == "__main__":
    unittest.main()
