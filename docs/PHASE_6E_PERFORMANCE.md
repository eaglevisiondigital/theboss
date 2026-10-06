# Phase 6E bounded performance

Status: final disposable workload passed. The disposable fixture uses 500 synthetic
athletes, 3,000 materialized origin summaries across all six supported sports and
30 separately versioned load definitions. No load people or fake contributions
are introduced into canonical Boss.

Evaluation consumes at most 50 subjects per batch and returns explicit remaining
work. Incremental completion and rebuild use the same adapters and uniqueness
constraints. Uncrossed synthetic thresholds must create no honors. Source scope
and game authorization is shared across each request rather than repeated for
every athlete. Profile/Family/showcase rendering reads bounded projections and
does not replay raw play-by-play.

Final full-run 50-subject batches measured Baseball 46.08 ms, Softball 34.91 ms,
Basketball 33.88 ms, Soccer 34.55 ms, Football 36.94 ms and Volleyball 34.85 ms
under the unchanged 8-second statement budget. All eleven workload assertions
passed. Context-free reads do not scan a global recognition feed, and history
queries select their exact recognition. No timeout, PostgreSQL tuning or unrelated
infrastructure change is authorized or required.

The complete post-fix rerun also passed: Baseball 45.75 ms, Softball 34.64 ms,
Basketball 35.11 ms, Soccer 34.03 ms, Football 33.19 ms and Volleyball 35.15 ms.
The same eleven assertions and eight-second budget apply. Earlier measurements
above are retained as prior evidence.
