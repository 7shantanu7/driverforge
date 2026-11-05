"""Reads CTest's JUnit XML (``ctest --output-junit``)."""

from __future__ import annotations

import xml.etree.ElementTree as ElementTree
from pathlib import Path
from typing import Dict, List

PASSED, FAILED, SKIPPED = "passed", "failed", "skipped"


def outcomes(path: Path) -> Dict[str, str]:
    """Maps test name to passed/failed/skipped."""
    root = ElementTree.parse(path).getroot()
    result: Dict[str, str] = {}
    for case in root.iter("testcase"):
        name = case.get("name", "")
        status = (case.get("status") or "").lower()
        if case.find("failure") is not None or case.find("error") is not None or status == "fail":
            result[name] = FAILED
        elif case.find("skipped") is not None or status in ("notrun", "disabled", "skipped"):
            result[name] = SKIPPED
        else:
            result[name] = PASSED
    return result


def summarize(path: Path, top: int = 5) -> dict:
    root = ElementTree.parse(path).getroot()
    cases = list(root.iter("testcase"))
    states = outcomes(path)
    timed = sorted(
        ((float(case.get("time", "0") or 0), case.get("name", "")) for case in cases),
        reverse=True,
    )
    return {
        "tests": len(states),
        "passed": sum(1 for s in states.values() if s == PASSED),
        "failed": sum(1 for s in states.values() if s == FAILED),
        "skipped": sum(1 for s in states.values() if s == SKIPPED),
        "seconds": round(sum(t for t, _ in timed), 3),
        "slowest": [{"test": name, "seconds": round(t, 3)} for t, name in timed[:top]],
    }


def find_flaky(runs: List[Path]) -> Dict[str, Dict[str, int]]:
    """Tests that both passed and failed across repeated runs of one commit.

    A test that always fails is broken, not flaky; a test that sometimes
    fails is the one that erodes trust in CI and belongs in quarantine.
    """
    tally: Dict[str, Dict[str, int]] = {}
    for run in runs:
        for name, state in outcomes(run).items():
            tally.setdefault(name, {PASSED: 0, FAILED: 0, SKIPPED: 0})[state] += 1
    return {name: t for name, t in sorted(tally.items()) if t[PASSED] and t[FAILED]}
