# Test summary

- Run date: 2026-07-26
- Environment: MATLAB 25.2.0.3177638 (R2025b) Update 5
- Test framework: `matlab.unittest`
- Test classes: 8
- Tests: 93
- Passed: 93
- Failed: 0
- Incomplete: 0
- Aggregate test duration reported by MATLAB: 8.282960500 s
- MATLAB Code Analyzer scope: 9 changed MATLAB files: the options entry
  point, the sequential runner, the high-dimensional registry and campaign
  runner, and 4 affected test classes
- MATLAB Code Analyzer findings in that scope: 0

The suite includes small end-to-end runs for COSSIN1, an all-infeasible BNH
initial design, an unconstrained two-objective problem, and a ten-dimensional
CF1 liveness/label-consistency case. It also verifies complete-pool
primary/challenger scoring and six-dimensional exact PoF anchors. These runs
are functional regression checks and do not constitute
optimizer-performance benchmarks.

The Code Analyzer statement excludes unchanged files and vendored third-party
code. Machine-readable per-test results are stored in `test-results.xml`.
