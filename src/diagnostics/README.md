# cTSEMO diagnostic figures

These functions create headless, publication-oriented MATLAB figures from the
canonical cTSEMO result struct. Every plotting function creates its figure with
`Visible="off"` and exports only through `exportgraphics`.

The field denoted by `p_i` is one clipped operational feasibility score. It is
not a Bernoulli posterior unless calibration is demonstrated separately.
`plotPofValidation` therefore plots conditional empirical distributions of the
same field and reports calibration diagnostics without calling them proof of
probabilistic calibration.

## Functions

- `generateReleaseFigures` regenerates the chapter-3 version-4 evidence
  package from the explicit
  `benchmark-results/release_shipped_profile_diagnostics_20260724/campaign_sources.csv`
  source map. The source map is restricted to the official 1024 primary
  candidates, 512 challengers, and 256 objective features profile and is
  checked against every loaded `result.mat` before plotting.
- `plot2DIterationAtlas` plots objective Thompson draws, raw and clipped
  feasibility fields, sampled HVI, both masks, final acquisition, and fallback
  score. It reads immutable full iteration files when available and marks
  unavailable summary-only fields instead of reconstructing them.
- `plotOptimizationHistory` plots the logged point-selection source,
  feasibility discovery, and hypervolume recomputed at one fixed reference.
- `plotPofValidation` reports conditional ECDFs, ROC/AUC, Brier score,
  reliability, and false-feasible/false-infeasible confusion counts.
- `plotParetoFront` plots observed feasible and infeasible objective vectors,
  the final nondominated front, and optional provenance-labelled overlays.
- `computeSortedPofRaster4D` evaluates the final clipped field in chunks and
  constructs the diagonal rank plane. Truth never participates in score
  sorting or tie breaking.
- `plotSortedPofRaster4D` plots the score, true feasibility, and unambiguous
  threshold-error categories at identical rank positions.
- `plotWeldedBeamPilotComparison` loads explicitly supplied CSV fronts and
  labels the comparison exploratory and unmatched. It computes no solver
  ranking, including for PAC-MOO.

## Minimal examples

```matlab
addpath("C:\path\to\cTSEMO-release");
addpath("C:\path\to\cTSEMO-release\diagnostics");
addpath("C:\path\to\cTSEMO-release\benchmarks");

% Package-local output; the external competitor overlay is skipped by default.
generateReleaseFigures(RunWbRaster=false);

problem = getBenchmarkProblem("COSSIN2");

plotOptimizationHistory(result, ...
    OutputFile="figures/cossin2_history.pdf");

plot2DIterationAtlas(result, numel(result.iterations), ...
    Problem=problem, ...
    OutputFile="figures/cossin2_final_atlas.png");
```

For an independent validation grid:

```matlab
[x1, x2] = meshgrid(linspace(0, 1, 201));
XValidation = [x1(:), x2(:)];
truth = problem.feasible(XValidation);
XObservedUnit = (result.data.X - problem.lowerBound) ./ ...
    (problem.upperBound - problem.lowerBound);
XValidationUnit = (XValidation - problem.lowerBound) ./ ...
    (problem.upperBound - problem.lowerBound);
pofModel = ctsemo.fitClippedBinaryPof( ...
    XObservedUnit, result.data.isFeasible, result.options);
pofOnValidationGrid = ctsemo.predictClippedBinaryPof( ...
    pofModel, XValidationUnit);

plotPofValidation(result, ...
    Score=pofOnValidationGrid, ...
    Truth=truth, ...
    Points=XValidation, ...
    Problem=problem, ...
    SampleDescription="Uniform 201-by-201 domain grid", ...
    OutputFile="figures/cossin2_pof_validation.pdf");
```

For a publication build outside the release tree, pass all external locations
explicitly. The comparator overlay is opt-in because its CSV sources are not
part of the shipped package:

```matlab
generateReleaseFigures( ...
    FigureDirectory="C:\path\to\paper\figures", ...
    DataDirectory="C:\path\to\paper\data", ...
    RunCompetitorOverlay=true, ...
    CompetitorSummaryFile="C:\path\to\competitor_summary.csv");
```

For the 4D welded-beam rank raster:

```matlab
problem = getBenchmarkProblem("WELDEDBEAM");
raster = computeSortedPofRaster4D(result, problem, ...
    PointsPerDimension=50, ...
    ChunkSize=100000, ...
    GridPlacement="cellCenters", ...
    OutputFile="figures/wb_sorted_pof_raster_data.mat");

plotSortedPofRaster4D(raster, ...
    OutputFile="figures/wb_sorted_pof_raster.png");
```

The default 4D call evaluates `50^4 = 6,250,000` points. Use a smaller
`PointsPerDimension` for code checks. The default points are cell centers;
`GridPlacement="endpoints"` is available when boundary-inclusive sampling is
required. The raster is a rank-layout diagnostic, not a continuous
two-dimensional projection of the four-dimensional domain.

Each function returns a metadata struct containing a cautious caption and
source/provenance fields. Callers should retain that metadata with the exported
figure.
