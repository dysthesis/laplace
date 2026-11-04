import importlib.util
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


class TimeoutTests(unittest.TestCase):
    def test_missing_echo_is_not_a_latency_sample(self):
        p = mock.Mock(buf=bytearray())
        p.pump_until.return_value = (False, 2.0, False)
        with mock.patch.object(probe, "_drain"):
            self.assertIsNone(probe._keystroke_lag(p, b"a", 0.1))

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

    def test_exit_measurements_obey_the_probe_timeout(self):
        with tempfile.TemporaryDirectory() as tmp:
            shell = Path(tmp) / "slow-shell"
            shell.write_text(f"#!{shutil.which('bash')}\nexec sleep 10\n")
            shell.chmod(0o755)
            args = SimpleNamespace(shell=str(shell), login=False, prompt_runs=1, timeout_ms=30)
            self.assertEqual(probe.measure_exit_time(args, dict(os.environ)), [])


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
                    self.assertFalse(out.exists())

    def test_isolated_directories_are_removed_on_success_and_failure(self):
        cases = (
            (["--targets", "fish", "--tiers", "metrics"], False, 0),
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
                        "nix": "printf '/unused\\n'",
                        "jq": "printf '{}\\n'",
                        "git": "exit 0",
                        "python3": (
                            '[[ $1 == *pty-probe.py ]] || exit 0\n'
                            'printf "%s\\n" "$HOME" "$XDG_RUNTIME_DIR" >"$CAPTURE"\n'
                            'printf "{}\\n"\nexit "$PROBE_STATUS"'
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
                            "PROBE_STATUS": str(status),
                        },
                        capture_output=True, text=True, timeout=10,
                    )
                    self.assertEqual(result.returncode, status, result.stderr)
                    if capture.exists():
                        paths = capture.read_text().splitlines()
                        self.assertEqual(len(paths), 2)
                        self.assertTrue(all(Path(p).parent == root for p in paths))
                        self.assertTrue(all(not Path(p).exists() for p in paths))
                    else:
                        self.assertTrue(missing_runtime, result.stderr)
                    self.assertEqual(list(root.glob("bench-*")), [])
                    self.assertTrue(root.is_dir())


if __name__ == "__main__":
    unittest.main()
