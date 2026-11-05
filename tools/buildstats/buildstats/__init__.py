"""buildstats: build and test metrics for CI.

Turns raw build-system output (Ninja's .ninja_log, ccache statistics, CTest
JUnit XML) into one JSON document per CI run, renders it as Markdown for the
job summary, compares it against a baseline to catch build-time regressions,
and finds flaky tests across repeated runs.

Standard library only, so it runs on any CI agent with Python 3.8+.
"""

__version__ = "1.0.0"
