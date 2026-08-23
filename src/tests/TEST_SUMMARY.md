# Test summary

- Run date: 2026-08-09
- Environment: MATLAB 25.2.0.3177638 (R2025b) Update 5
- Test framework: `matlab.unittest`
- Test classes: 9
- Tests: 105
- Passed: 105
- Failed: 0
- Incomplete: 0
- Aggregate test duration reported by MATLAB: 7.797053500 s
- MATLAB Code Analyzer scope: 8 changed MATLAB files: the options entry
  point, sequential runner, acquisition scorer, GA helper, and 4 affected
  test classes
- MATLAB Code Analyzer findings in that scope: 0

The suite includes small end-to-end runs for COSSIN1, an all-infeasible BNH
initial design, an unconstrained two-objective problem, and a ten-dimensional
CF1 liveness/label-consistency case. It also verifies bounded GA search,
non-regression relative to the best primary seed, deterministic replay and
random-stream restoration, fixed-background acquisition scoring,
same-acquisition LHS challenger arbitration, and six-dimensional exact PoF
anchors. These runs are functional regression
checks and do not constitute optimizer-performance benchmarks.

The Code Analyzer statement excludes unchanged files and vendored third-party
code. Machine-readable per-test results are stored in `test-results.xml`.
