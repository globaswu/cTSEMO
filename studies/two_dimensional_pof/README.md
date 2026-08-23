# Current-source two-dimensional PoF study

This study runs four deterministic, two-variable constrained multiobjective
benchmarks with the exact cTSEMO source in this repository. It is intended to
show how the clipped Gaussian-process mean feasibility score changes as binary
feasibility labels accumulate. It is not a matched multi-seed comparison with
other solvers.

## Run the complete campaign

In MATLAB, change to the repository root and run:

```matlab
setup_ctsemo;
reproduce_two_dimensional_pof_results;
```

The campaign consists of:

| Problem | Initial design | Sequential evaluations | Seeds (initial / solver) |
|---|---:|---:|---:|
| COSSIN1 | 20 | 30 | 2026072401 / 2026072501 |
| COSSIN2 | 20 | 60 | 2026072402 / 2026072502 |
| BNH | 10 | 30 | 2026072403 / 2026072503 |
| SRN | 10 | 30 | 2026072405 / 2026072505 |

All initial designs include the four corners. Each optimization uses 1,024
primary candidates, 512 challenger candidates, 256 objective random Fourier
features, complete-pool challenger scoring, and full iteration logging.

To regenerate the grids and figures without rerunning the optimizations:

```matlab
reproduce_two_dimensional_pof_results("ReuseResults", true);
```

Figures are hidden while the script runs. Set `"ShowFigures", true` only when
interactive display is wanted.

Two final manuscript composites use Python after the MATLAB reconstruction:

```powershell
python studies/two_dimensional_pof/make_cossin2_acquisition_decomposition.py
python studies/two_dimensional_pof/build_shared_classification_legend.py
```

Install their tested dependencies from the repository-root
`requirements.txt` file.

## Diagnostic protocol

The fitted field is evaluated on an independent 201 by 201 cell-centred grid
in the normalized square `[0,1]^2`. A grid point is classified as predicted
feasible when `p_i >= 0.5`; exact equality is therefore assigned to the
feasible class. The figures use a common score range of `[0,1]` and square
plotting boxes.

On the continuous-score maps, the solid white curve is the learned
`p_i = 0.5` contour and the dashed black curve is the exact benchmark
feasibility boundary. Exact truth is evaluated only after optimization for
offline diagnostics. It is not exposed to the acquisition function.

The reported false-feasible and false-infeasible rates are conditional error
rates:

- false-feasible rate: fraction of exactly violating grid points classified
  as feasible;
- false-infeasible rate: fraction of exactly feasible grid points classified
  as violating.

The area under the receiver-operating-characteristic curve (AUC), Brier
score, ten-bin expected calibration error, balanced accuracy, endpoint
fractions, and exact-anchor error are also reported. The score is an
operational feasibility field rather than a claimed calibrated Bernoulli
probability, so calibration metrics are diagnostics rather than proof of a
probabilistic interpretation.

## Outputs

Stable artifacts are stored in
[`manuscript/artifacts/two_dimensional_campaign`](../../manuscript/artifacts/two_dimensional_campaign/).
The source manifest records SHA-256 hashes of the study and release source.
The manifest CSV itself has an authoritative digest in
`source_manifest.sha256`. Numeric CSV files are written by MATLAB `writetable`
using its default numeric serialization; the MAT record is the full-precision
authority for derived fields and run data.
