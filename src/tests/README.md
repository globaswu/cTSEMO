# cTSEMO test suite

The tests use `matlab.unittest.TestCase` classes and exercise only public
release interfaces. From the release root, run:

```matlab
results = runtests(fullfile(pwd, "tests"));
assertSuccess(results);
```

The suite covers:

- binary-label conversion, nonfinite constraints, option validation, and
  duplicate-label conflicts;
- exact clipped binary-GP anchors, adjustable raw targets, clipping,
  one-class data, duplicates, and two-/four-dimensional local kernels;
- objective-GP prediction, deterministic Thompson draws, component seeds,
  caller random-stream restoration, and base-MATLAB spectral-quantile
  equivalence;
- Pareto utilities, exact two-objective hypervolume, sampled HVI,
  anti-clustering masks, bounded GA primary search seeded from the primary
  design, same-acquisition LHS challenger arbitration, hard
  duplicate exclusion, configurable PoF powers, adaptive HVI background,
  and exhausted-pool fallback signaling;
- deterministic benchmark initial designs, including an all-infeasible BNH
  stress design; and
- small end-to-end COSSIN, repeated all-infeasible Phase-I, and
  unconstrained solver runs, including reconstruction of stored sampled HVI
  and acquisition values.

The end-to-end tests deliberately use small seed/challenger designs, small GA
populations, and short
evaluation budgets. They are regression and liveness checks, not benchmark
performance evidence.
