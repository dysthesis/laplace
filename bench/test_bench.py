import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
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


class TimeoutTests(unittest.TestCase):
    def test_missing_echo_is_not_a_latency_sample(self):
        p = mock.Mock(buf=bytearray())
        p.pump_until.return_value = (False, 2.0, False)
        with mock.patch.object(probe, "_drain"):
            self.assertIsNone(probe._keystroke_lag(p, b"a", 0.1))
        p.write.assert_any_call(b"\x7f")

    def test_incomplete_redraw_is_not_a_latency_sample(self):
        args = SimpleNamespace(
            shell="/unused/fish", login=False, no_interactive=False,
            shell_arg=[], no_raw=False, cols=120, rows=30,
            prompt_regex=None, quiesce_ms=120, timeout_ms=100,
            prompt_runs=1, inner_iters=1, longbuf_len=200,
        )
        p = mock.Mock(t0=1.0)
        p.spawn.return_value = p
        p.pump_until.side_effect = [(True, 2.0, False), (False, 3.0, False)]
        with (
            mock.patch.object(probe, "Pty", return_value=p),
            mock.patch.object(probe, "_drain"),
            mock.patch.object(probe, "_keystroke_lag", return_value=0.1),
        ):
            samples = probe.measure_spawn_metrics(args, {})
        self.assertEqual(samples["command_lag_ms"], [None])
        p.close.assert_called_once()

    def test_exit_measurements_obey_the_probe_timeout(self):
        args = SimpleNamespace(shell="/unused/fish", login=False, prompt_runs=1, timeout_ms=100)
        with mock.patch("subprocess.run", side_effect=subprocess.TimeoutExpired("fish", 0.1)) as run:
            self.assertEqual(probe.measure_exit_time(args, {}), [])
        self.assertEqual(run.call_args.kwargs["timeout"], 0.1)


class AblationTests(unittest.TestCase):
    def test_generated_hook_can_be_disabled_without_a_plugin_loader(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            cfg = root / "user_config.fish"
            original = (
                "source /nix/store/example-direnv.fish\n"
                "source /nix/store/example-starship-init.fish\n"
            )
            cfg.write_text(original)
            share = root / "ablation" / "share"
            result = subprocess.run(
                [shutil.which("bash"), "-euc",
                 'source "$1"; gen_ablation_config "$2" "$3" "$4"',
                 "ablation-test", str(HERE / "lib.sh"), str(share.parent), str(cfg),
                 r"direnv\.fish"],
                capture_output=True, text=True, timeout=5,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), str(share))
            self.assertEqual(
                (share / "fish/vendor_conf.d/user_config.fish").read_text(),
                "# ABLATED: " + original,
            )
            self.assertEqual(cfg.read_text(), original)


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
                    stats.cmd_summarise([self.path], as_json)
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

    def test_statistics_cli_uses_british_spelling(self):
        output = io.StringIO()
        with (
            mock.patch("sys.argv", ["stats.py", "summarise", self.path, "--json"]),
            contextlib.redirect_stdout(output),
        ):
            stats.main()
        self.assertEqual(json.loads(output.getvalue())[0]["label"], "sample")

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

    def test_isolated_directories_are_removed_on_success_and_failure(self):
        cases = (
            (["--targets", "fish", "--tiers", "metrics"], False, 0),
            (["--targets", "bash", "--tiers", "metrics"], False, 0),
            (["--targets", "devshell", "--tiers", "metrics"], False, 0),
            (["--targets", "fish", "--tiers", "attrib", "--no-ablation"], False, 0),
            (["--ab", "/unused/A", "/unused/B", "--tiers", "metrics"], False, 7),
            (["--targets", "fish", "--tiers", "metrics"], True, 1),
        )
        for args, missing_runtime, status in cases:
            with self.subTest(args=args, missing_runtime=missing_runtime):
                with tempfile.TemporaryDirectory() as tmp:
                    root = Path(tmp)
                    tools = root / "bin"
                    tools.mkdir()
                    for name, body in {
                        "nix": (
                            'if [[ $1 == build ]]; then printf "%s\\n" "$@" >>"$NIX_CALLS"; fi\n'
                            "printf '/unused\\n'"
                        ),
                        "jq": "printf '{}\\n'",
                        "git": "exit 0",
                        "python3": (
                            '[[ $1 != --version ]] || exit 0\n'
                            'printf "%s\\n" "$HOME" "$XDG_RUNTIME_DIR" >"$CAPTURE"\n'
                            'printf "%s\\n" "$@" >>"$CAPTURE.args"\n'
                            "exit 7"
                        ),
                    }.items():
                        tool = tools / name
                        tool.write_text(f"#!{shutil.which('bash')}\nset -eu\n{body}\n")
                        tool.chmod(0o755)
                    capture = root / "environment"
                    result = subprocess.run(
                        [shutil.which("bash"), str(HERE / "shell-bench.sh"),
                         "--out", str(root / "results"), *args],
                        cwd=tmp, env={
                            **os.environ, "PATH": f"{tools}{os.pathsep}{os.environ['PATH']}",
                            "TMPDIR": tmp, "XDG_RUNTIME_DIR": str(root / "missing") if missing_runtime else tmp,
                            "CAPTURE": str(capture), "BENCH_LIB": str(HERE), "BENCH_CORE": "",
                            "NIX_CALLS": str(root / "builds"),
                        },
                        capture_output=True, text=True, timeout=10,
                    )
                    self.assertEqual(result.returncode, status, result.stderr)
                    if capture.exists():
                        paths = capture.read_text().splitlines()
                        self.assertEqual(len(paths), 2)
                        self.assertTrue(all(Path(p).parent == root for p in paths))
                        self.assertTrue(all(not Path(p).exists() for p in paths))
                        probe_args = Path(f"{capture}.args").read_text().splitlines()
                        self.assertNotIn("--prompt-regex", probe_args)
                        self.assertEqual(probe_args.count("--no-raw"), int("bash" in args))
                    else:
                        self.assertTrue(missing_runtime or "metrics" not in args or "devshell" in args, result.stderr)
                    self.assertEqual(list(root.glob("bench-*")), [])
                    self.assertTrue(root.is_dir())
                    build_args = (root / "builds").read_text().splitlines() if (root / "builds").exists() else []
                    attrs = [arg for arg in build_args if "#" in arg]
                    if "--ab" in args or "devshell" in args:
                        self.assertEqual(attrs, [])
                    else:
                        shell = args[args.index("--targets") + 1]
                        self.assertEqual(len(attrs), 1)
                        self.assertTrue(attrs[0].endswith(f".pkgs.configured.{shell}"), attrs)


if __name__ == "__main__":
    unittest.main()
