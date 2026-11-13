"""Command-line entry point: ``python3 -m buildstats <command> ...``."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import List, Optional

from . import ccache_stats, junit, ninja_log, report


def _cmd_ninja(args: argparse.Namespace) -> int:
    summary = ninja_log.summarize(ninja_log.parse_file(Path(args.build_dir) / ".ninja_log"), args.top)
    print(f"Top {args.top} slowest build steps in {args.build_dir} "
          f"({summary['steps']} steps, {summary['cpu_seconds']:.1f}s CPU, "
          f"{summary['wall_seconds']:.1f}s wall):\n")
    for step in summary["slowest"]:
        print(f"{step['seconds']:8.2f}s  {step['output']}")
    return 0


def _cmd_collect(args: argparse.Namespace) -> int:
    ninja = ninja_log.summarize(ninja_log.parse_file(Path(args.build_dir) / ".ninja_log"), args.top)
    ccache = None if args.no_ccache else ccache_stats.collect()
    tests = junit.summarize(Path(args.junit)) if args.junit and Path(args.junit).exists() else None
    doc = report.build_document(args.label, ninja, ccache, tests)
    text = json.dumps(doc, indent=2, sort_keys=True)
    if args.output:
        Path(args.output).write_text(text + "\n", encoding="utf-8")
    else:
        print(text)
    return 0


def _cmd_markdown(args: argparse.Namespace) -> int:
    doc = json.loads(Path(args.metrics).read_text(encoding="utf-8"))
    sys.stdout.write(report.to_markdown(doc))
    return 0


def _cmd_compare(args: argparse.Namespace) -> int:
    baseline_path = Path(args.baseline)
    if not baseline_path.exists():
        print(f"no baseline at {baseline_path}; nothing to compare (first run on this branch?)")
        return 0
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    warn_only = args.warn_only
    if isinstance(baseline, list):  # a history file: compare against its median
        samples = len(baseline)
        baseline = report.baseline_from_history(baseline)
        print(f"baseline: median of {samples} previous night(s)")
        if samples < args.min_samples:
            print(f"fewer than {args.min_samples} nights recorded; reporting only, not failing")
            warn_only = True
    current = json.loads(Path(args.current).read_text(encoding="utf-8"))
    ok, messages = report.compare(baseline, current, args.max_regression, args.min_seconds)
    for message in messages:
        print(message)
    return 0 if ok or warn_only else 1


def _cmd_history(args: argparse.Namespace) -> int:
    path = Path(args.history)
    history = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    current = json.loads(Path(args.current).read_text(encoding="utf-8"))
    history.append(report.history_entry(current))
    path.write_text(json.dumps(history[-args.keep:], indent=2) + "\n", encoding="utf-8")
    return 0


def _cmd_flaky(args: argparse.Namespace) -> int:
    flaky = junit.find_flaky([Path(p) for p in args.runs])
    if not flaky:
        print(f"no flaky tests across {len(args.runs)} runs")
        return 0
    print(f"{len(flaky)} flaky test(s) across {len(args.runs)} runs:")
    for name, tally in flaky.items():
        print(f"  {name}: {tally['passed']} passed, {tally['failed']} failed")
    return 1


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="buildstats", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("ninja", help="print the slowest steps of the last Ninja build")
    p.add_argument("build_dir")
    p.add_argument("--top", type=int, default=10)
    p.set_defaults(func=_cmd_ninja)

    p = sub.add_parser("collect", help="write build/test metrics as JSON")
    p.add_argument("build_dir")
    p.add_argument("--label", default="build")
    p.add_argument("--junit", help="CTest JUnit XML from --output-junit")
    p.add_argument("--output", "-o", help="file to write (default stdout)")
    p.add_argument("--top", type=int, default=10)
    p.add_argument("--no-ccache", action="store_true")
    p.set_defaults(func=_cmd_collect)

    p = sub.add_parser("markdown", help="render metrics JSON as Markdown")
    p.add_argument("metrics")
    p.set_defaults(func=_cmd_markdown)

    p = sub.add_parser("compare", help="fail if compile time regressed against a baseline (metrics file or history file)")
    p.add_argument("baseline")
    p.add_argument("current")
    p.add_argument("--max-regression", type=float, default=0.25,
                   help="allowed growth as a fraction (default 0.25 = 25%%)")
    p.add_argument("--min-seconds", type=float, default=5.0,
                   help="ignore growth smaller than this many seconds")
    p.add_argument("--min-samples", type=int, default=1,
                   help="with a history file, only fail once this many nights are recorded")
    p.add_argument("--warn-only", action="store_true")
    p.set_defaults(func=_cmd_compare)

    p = sub.add_parser("history", help="append a night's metrics to a rolling history file")
    p.add_argument("history")
    p.add_argument("current")
    p.add_argument("--keep", type=int, default=7)
    p.set_defaults(func=_cmd_history)

    p = sub.add_parser("flaky", help="find tests with mixed results across repeated runs")
    p.add_argument("runs", nargs="+", help="JUnit XML files from repeated ctest runs")
    p.set_defaults(func=_cmd_flaky)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
