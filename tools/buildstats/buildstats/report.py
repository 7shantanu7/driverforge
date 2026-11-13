"""Combines collected metrics, renders Markdown, compares runs."""

from __future__ import annotations

import os
import statistics
from typing import List, Optional, Tuple

SCHEMA_VERSION = 1


def metadata() -> dict:
    env = os.environ
    return {
        "commit": env.get("GITHUB_SHA") or env.get("CI_COMMIT_SHA") or env.get("GIT_COMMIT"),
        "ref": env.get("GITHUB_REF_NAME") or env.get("CI_COMMIT_REF_NAME") or env.get("BRANCH_NAME"),
        "run_id": env.get("GITHUB_RUN_ID") or env.get("CI_PIPELINE_ID") or env.get("BUILD_ID"),
        "runner": env.get("RUNNER_NAME") or env.get("CI_RUNNER_DESCRIPTION") or env.get("NODE_NAME"),
    }


def build_document(label: str, ninja: dict, ccache: Optional[dict], tests: Optional[dict]) -> dict:
    return {
        "schema": SCHEMA_VERSION,
        "label": label,
        "meta": metadata(),
        "build": ninja,
        "ccache": ccache,
        "tests": tests,
    }


def to_markdown(doc: dict) -> str:
    build = doc.get("build") or {}
    lines = [
        f"### Build metrics: `{doc.get('label', 'build')}`",
        "",
        "| Metric | Value |",
        "| --- | --- |",
        f"| Build steps | {build.get('steps', 0)} |",
        f"| Wall time | {build.get('wall_seconds', 0):.1f} s |",
        f"| Total compile CPU time | {build.get('cpu_seconds', 0):.1f} s |",
    ]
    ccache = doc.get("ccache")
    if ccache and ccache.get("hit_rate") is not None:
        lines.append(
            f"| ccache hit rate | {ccache['hit_rate'] * 100:.1f}% "
            f"({ccache['hits']} hits, {ccache['misses']} misses) |"
        )
    tests = doc.get("tests")
    if tests:
        lines.append(
            f"| Tests | {tests['passed']} passed, {tests['failed']} failed, "
            f"{tests['skipped']} skipped ({tests['seconds']:.1f} s) |"
        )
    slowest = build.get("slowest") or []
    if slowest:
        lines += ["", "<details><summary>Slowest build steps</summary>", "", "| Seconds | Output |",
                  "| ---: | --- |"]
        lines += [f"| {s['seconds']:.2f} | `{s['output']}` |" for s in slowest]
        lines += ["", "</details>"]
    return "\n".join(lines) + "\n"


def compare(
    baseline: dict, current: dict, max_regression: float, min_seconds: float
) -> Tuple[bool, List[str]]:
    """Flags a regression when compile CPU time grows by more than
    ``max_regression`` (a fraction) AND by more than ``min_seconds``. CPU
    time is used instead of wall time because it is much less sensitive to
    how busy a shared CI runner happens to be."""
    messages: List[str] = []
    ok = True
    old = (baseline.get("build") or {}).get("cpu_seconds", 0.0)
    new = (current.get("build") or {}).get("cpu_seconds", 0.0)
    delta = new - old
    ratio = (delta / old) if old else 0.0
    messages.append(f"compile CPU time: {old:.1f}s -> {new:.1f}s ({ratio:+.1%})")
    if old and ratio > max_regression and delta > min_seconds:
        ok = False
        messages.append(
            f"REGRESSION: compile time grew {ratio:.1%}, limit is {max_regression:.0%}"
        )

    old_tests = (baseline.get("tests") or {}).get("tests")
    new_tests = (current.get("tests") or {}).get("tests")
    if old_tests and new_tests is not None and new_tests < old_tests:
        messages.append(f"note: test count dropped from {old_tests} to {new_tests}")
    return ok, messages


def history_entry(doc: dict) -> dict:
    """The slice of a metrics document that is worth keeping night to night."""
    return {
        "run_id": (doc.get("meta") or {}).get("run_id"),
        "cpu_seconds": (doc.get("build") or {}).get("cpu_seconds", 0.0),
        "tests": (doc.get("tests") or {}).get("tests"),
    }


def baseline_from_history(history: List[dict]) -> dict:
    """A baseline document whose compile time is the MEDIAN of the recorded
    nights. A single slow (or fast) runner then cannot move the baseline,
    which a previous-night-only comparison could not guarantee."""
    cpu = [h["cpu_seconds"] for h in history if h.get("cpu_seconds")]
    tests = next((h["tests"] for h in reversed(history) if h.get("tests")), None)
    return {
        "build": {"cpu_seconds": statistics.median(cpu) if cpu else 0.0},
        "tests": {"tests": tests},
    }
