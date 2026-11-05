"""Parser for Ninja's .ninja_log (format v5 and v6)."""

from __future__ import annotations

import dataclasses
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


@dataclasses.dataclass(frozen=True)
class Step:
    """One build edge: the command that produced ``output``."""

    start_ms: int
    end_ms: int
    output: str
    command_hash: str

    @property
    def duration_s(self) -> float:
        return (self.end_ms - self.start_ms) / 1000.0


class NinjaLogError(ValueError):
    pass


def parse_lines(lines: Iterable[str]) -> List[Step]:
    """Returns the steps of the MOST RECENT build in the log.

    The log is append-only across builds and a step that ran again is
    appended again, so the last entry for each output wins. Ninja restarts
    its millisecond clock at 0 for every build and appends entries in the
    order steps FINISH, so within one build end times never decrease. An end
    time lower than the previous one marks the start of a new build (the
    same rule ninjatracing uses).
    """
    iterator = iter(lines)
    header = next(iterator, "").strip()
    if not header.startswith("# ninja log v"):
        raise NinjaLogError(f"not a ninja log (header was {header!r})")
    version = int(header.rsplit("v", 1)[1])
    if version not in (5, 6):
        raise NinjaLogError(f"unsupported ninja log version {version}")

    builds: List[Dict[str, Step]] = [{}]
    previous_end = -1
    for raw in iterator:
        line = raw.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) < 5:
            raise NinjaLogError(f"malformed ninja log line: {line!r}")
        start, end = int(fields[0]), int(fields[1])
        if end < previous_end and builds[-1]:
            builds.append({})
        previous_end = end
        builds[-1][fields[3]] = Step(start, end, fields[3], fields[4])

    latest = builds[-1]
    return sorted(latest.values(), key=lambda step: (step.start_ms, step.output))


def parse_file(path: Path) -> List[Step]:
    with Path(path).open(encoding="utf-8") as handle:
        return parse_lines(handle)


def unique_commands(steps: Iterable[Step]) -> List[Step]:
    """One step per command: an edge with several outputs (a library and its
    symlinks) is logged once per output with identical timing."""
    seen: Dict[Tuple[int, int, str], Step] = {}
    for step in steps:
        seen.setdefault((step.start_ms, step.end_ms, step.command_hash), step)
    return list(seen.values())


def summarize(steps: List[Step], top: int = 10) -> dict:
    commands = unique_commands(steps)
    if not commands:
        return {"steps": 0, "cpu_seconds": 0.0, "wall_seconds": 0.0, "slowest": []}
    wall = (max(s.end_ms for s in commands) - min(s.start_ms for s in commands)) / 1000.0
    slowest = sorted(commands, key=lambda s: s.duration_s, reverse=True)[:top]
    return {
        "steps": len(commands),
        "cpu_seconds": round(sum(s.duration_s for s in commands), 3),
        "wall_seconds": round(wall, 3),
        "slowest": [{"output": s.output, "seconds": round(s.duration_s, 3)} for s in slowest],
    }
