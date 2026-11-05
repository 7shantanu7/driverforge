import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from buildstats import __main__ as cli
from buildstats import ccache_stats, junit, ninja_log, report

DATA = Path(__file__).parent / "data"


class NinjaLogTest(unittest.TestCase):
    def test_keeps_only_most_recent_build(self):
        steps = ninja_log.parse_file(DATA / "two_builds.ninja_log")
        # The second build (clock restarted at 0) only rebuilt core/a.o.
        self.assertEqual([s.output for s in steps], ["core/a.o"])
        self.assertAlmostEqual(steps[0].duration_s, 0.5)

    def test_summarize_dedupes_multi_output_edges(self):
        lines = (DATA / "two_builds.ninja_log").read_text().splitlines(True)[:5]
        summary = ninja_log.summarize(ninja_log.parse_lines(lines), top=2)
        self.assertEqual(summary["steps"], 3)  # .so and its symlink are one command
        self.assertEqual(summary["slowest"][0]["output"], "core/b.o")
        self.assertAlmostEqual(summary["wall_seconds"], 3.5)
        self.assertAlmostEqual(summary["cpu_seconds"], 1.19 + 3.4 + 0.1)

    def test_rejects_non_ninja_files(self):
        with self.assertRaises(ninja_log.NinjaLogError):
            ninja_log.parse_lines(["hello\n"])

    def test_rejects_unknown_versions(self):
        with self.assertRaises(ninja_log.NinjaLogError):
            ninja_log.parse_lines(["# ninja log v4\n"])


class CcacheTest(unittest.TestCase):
    def test_hit_rate(self):
        stats = ccache_stats.parse_print_stats(
            "direct_cache_hit\t6\npreprocessed_cache_hit\t2\ncache_miss\t2\nstats_updated_timestamp\t0\n"
        )
        summary = ccache_stats.summarize(stats)
        self.assertEqual(summary["hits"], 8)
        self.assertEqual(summary["hit_rate"], 0.8)

    def test_no_lookups_means_unknown_rate(self):
        self.assertIsNone(ccache_stats.summarize({})["hit_rate"])


class JunitTest(unittest.TestCase):
    def test_summary_counts(self):
        summary = junit.summarize(DATA / "run_fail.xml")
        self.assertEqual((summary["passed"], summary["failed"], summary["skipped"]), (1, 1, 1))
        self.assertEqual(summary["slowest"][0]["test"], "B.Sometimes")

    def test_flaky_needs_both_pass_and_fail(self):
        flaky = junit.find_flaky([DATA / "run_pass.xml", DATA / "run_fail.xml"])
        self.assertEqual(list(flaky), ["B.Sometimes"])

    def test_consistent_runs_are_not_flaky(self):
        self.assertEqual(junit.find_flaky([DATA / "run_pass.xml"] * 3), {})


class CompareTest(unittest.TestCase):
    def doc(self, cpu):
        return {"build": {"cpu_seconds": cpu}, "tests": {"tests": 10}}

    def test_large_regression_fails(self):
        ok, _ = report.compare(self.doc(100), self.doc(140), 0.25, 5)
        self.assertFalse(ok)

    def test_small_absolute_change_is_noise(self):
        ok, _ = report.compare(self.doc(2), self.doc(4), 0.25, 5)
        self.assertTrue(ok)

    def test_improvement_passes(self):
        ok, _ = report.compare(self.doc(100), self.doc(60), 0.25, 5)
        self.assertTrue(ok)


class CliTest(unittest.TestCase):
    def test_collect_then_markdown(self):
        with tempfile.TemporaryDirectory() as tmp:
            build = Path(tmp)
            (build / ".ninja_log").write_text((DATA / "two_builds.ninja_log").read_text())
            out = build / "metrics.json"
            self.assertEqual(
                cli.main(["collect", str(build), "--label", "t", "--junit",
                          str(DATA / "run_pass.xml"), "--no-ccache", "-o", str(out)]),
                0,
            )
            doc = json.loads(out.read_text())
            self.assertEqual(doc["schema"], report.SCHEMA_VERSION)
            buffer = io.StringIO()
            with redirect_stdout(buffer):
                cli.main(["markdown", str(out)])
            self.assertIn("Build metrics: `t`", buffer.getvalue())
            self.assertIn("1 skipped", buffer.getvalue())

    def test_flaky_exit_code(self):
        with redirect_stdout(io.StringIO()):
            self.assertEqual(cli.main(["flaky", str(DATA / "run_pass.xml"), str(DATA / "run_fail.xml")]), 1)
            self.assertEqual(cli.main(["flaky", str(DATA / "run_pass.xml")]), 0)

    def test_compare_without_baseline_is_not_an_error(self):
        with redirect_stdout(io.StringIO()):
            self.assertEqual(cli.main(["compare", "/nonexistent.json", "/nonexistent2.json"]), 0)


if __name__ == "__main__":
    unittest.main()
