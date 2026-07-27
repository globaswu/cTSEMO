# Code index

This index maps the main algorithmic and manuscript components to concise,
timestamp-free MATLAB paths.

## Public interface

| Component | MATLAB file |
|---|---|
| cTSEMO entry point | `src/cTSEMO.m` |
| Validated option construction | `src/cTSEMOOptions.m` |
| Sequential optimization loop | `src/+ctsemo/run.m` |

## Feasibility field

| Component | MATLAB file |
|---|---|
| Fit clipped GP-mean field | `src/+ctsemo/fitClippedBinaryPof.m` |
| Evaluate and clip the field | `src/+ctsemo/predictClippedBinaryPof.m` |
| Locally variable Matérn-3/2 covariance | `src/+ctsemo/localMatern32.m` |
| Convert observations to aggregate binary labels | `src/+ctsemo/binaryLabels.m` |

## Acquisition and safeguards

| Component | MATLAB file |
|---|---|
| Thompson-sampled hypervolume improvement | `src/+ctsemo/sampledHVI.m` |
| PoF weighting and final candidate scores | `src/+ctsemo/scoreCandidates.m` |
| Design- and objective-space masks | `src/+ctsemo/crowdingMasks.m` |
| Primary and challenger candidate pools | `src/+ctsemo/makeCandidatePools.m` |
| Feasibility-discovery and recovery selection | `src/+ctsemo/selectFallback.m` |

## Manuscript figures

| Manuscript artifact | MATLAB file |
|---|---|
| Six-method PoF atlas | `manuscript/introduction_pof_comparison/run_introduction_pof_comparison.m` |
| Bernoulli-GPC versus proposed clipped GP-mean field | `manuscript/introduction_pof_comparison/run_introduction_pof_comparison.m` |
| Matched-dimension summary figures | `studies/dimension_matched_pof/plot_manuscript_dimension_figures.m` |

## Benchmarks and diagnostics

| Component | MATLAB file |
|---|---|
| Benchmark registry | `src/benchmarks/getBenchmarkProblem.m` |
| Release benchmark campaign | `src/benchmarks/runReleaseBenchmarks.m` |
| Benchmark summary | `src/benchmarks/summarizeReleaseBenchmarks.m` |
| Diagnostic figure dispatcher | `src/diagnostics/generateReleaseFigures.m` |
| Two-dimensional iteration atlas | `src/diagnostics/plot2DIterationAtlas.m` |
| Four-dimensional sorted PoF raster | `src/diagnostics/plotSortedPofRaster4D.m` |
| PoF validation diagnostics | `src/diagnostics/plotPofValidation.m` |

## Dimension study

| Task | MATLAB file |
|---|---|
| Launch the full campaign | `studies/dimension_matched_pof/launch_full_study.m` |
| Run a configurable campaign | `studies/dimension_matched_pof/run_matched_dimension_pof_study.m` |
| Plot campaign diagnostics | `studies/dimension_matched_pof/plot_matched_dimension_pof_study.m` |
| Validate generated campaign files | `studies/dimension_matched_pof/validate_matched_dimension_pof_study.m` |
| Summarize dimension trends | `studies/dimension_matched_pof/summarize_dimension_trend.m` |
| Seal a source manifest | `studies/dimension_matched_pof/seal_dimension_study_sources.m` |
