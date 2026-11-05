"""Reads ccache statistics via ``ccache --print-stats`` (ccache >= 4.4)."""

from __future__ import annotations

import shutil
import subprocess
from typing import Dict, Optional


def parse_print_stats(text: str) -> Dict[str, int]:
    """Parses the tab-separated ``key<TAB>value`` output of --print-stats."""
    stats: Dict[str, int] = {}
    for line in text.splitlines():
        key, sep, value = line.partition("\t")
        if sep and value.strip().lstrip("-").isdigit():
            stats[key.strip()] = int(value)
    return stats


def summarize(stats: Dict[str, int]) -> dict:
    hits = stats.get("direct_cache_hit", 0) + stats.get("preprocessed_cache_hit", 0)
    misses = stats.get("cache_miss", 0)
    lookups = hits + misses
    return {
        "hits": hits,
        "misses": misses,
        "hit_rate": round(hits / lookups, 4) if lookups else None,
    }


def collect(ccache: str = "ccache") -> Optional[dict]:
    if shutil.which(ccache) is None:
        return None
    try:
        result = subprocess.run(
            [ccache, "--print-stats"], check=True, capture_output=True, text=True, timeout=30
        )
    except (subprocess.SubprocessError, OSError):
        return None
    return summarize(parse_print_stats(result.stdout))
