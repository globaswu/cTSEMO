# Diagnostic utilities

These functions create headless figures from a canonical cTSEMO result struct.
Run `setup_ctsemo` first and pass output files explicitly.

- `plot2DIterationAtlas` plots objective Thompson draws, feasibility score,
  sampled HVI, masks, and acquisition for a stored iteration.
- `plotOptimizationHistory` plots selection source, feasibility discovery, and
  hypervolume at a stated fixed reference.
- `plotPofValidation` reports ECDF, ROC/AUC, mean squared score error,
  reliability, and threshold errors on an independently supplied probe set.
- `plotParetoFront` plots observed feasible and violating objectives and the
  feasible nondominated front.
- `computeSortedPofRaster4D` and `plotSortedPofRaster4D` build the optional
  four-dimensional rank-plane diagnostic.

Example:

```matlab
setup_ctsemo;
problem = getBenchmarkProblem("COSSIN2");
plotOptimizationHistory(result, ...
    OutputFile=fullfile("figures", "cossin2_history.pdf"));
plot2DIterationAtlas(result, numel(result.iterations), ...
    Problem=problem, ...
    OutputFile=fullfile("figures", "cossin2_final_atlas.pdf"));
```

`generateReleaseFigures` is retained only for the archived v0.1 campaign
schema and requires an explicit compatible `CampaignRoot`. It is not used to
generate the current manuscript figures. Current figure entry points are
listed in `docs/RESULTS_MAP.md`.

Exact benchmark truth is accepted only for offline diagnostics. It must never
be supplied to the sequential candidate-selection path.
