# Fixed-budget dimension study of binary feasibility fields

## Outcome

The results suggest that the shipped clipped GP-mean feasibility field can
become less informative as dimension increases at a fixed 150-evaluation
budget. They do not support the stronger proposition that every false rate
must increase, or that deterioration is independent of the PoF
formulation.

The cleanest tested contrast is CF1, for which the independent probe
feasible rate remains similar in D4 (49.66%) and D10 (52.40%). For the
clipped GP mean, the paired median balanced-error increase was 8.88
percentage points and occurred in 5/5 seeds. This change was dominated by a
17.64-point increase in false-infeasible rate; false-feasible rate changed
by only -0.06 points. Median ROC AUC decreased by 0.130.

The offline RF proxy did not reproduce the same CF1 balanced-error trend.
Its paired median balanced error decreased by 1.12 points, with increases
in only 2/5 seeds. Its false-feasible rate increased by 15.12 points while
its false-infeasible rate decreased by 13.97 points. Thus dimension changed
the two error types differently, and the direction depended on the field
formulation.

## Median final field diagnostics

| Problem | D | Probe feasible | GP AUC | GP FPR | GP FNR | GP balanced error | RF AUC | RF FPR | RF FNR | RF balanced error |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Welded beam | 4 | 33.27% | 0.945 | 9.98% | 13.70% | 12.17% | 0.950 | 25.00% | 4.18% | 13.84% |
| CF1 | 4 | 49.66% | 0.805 | 10.03% | 51.54% | 32.79% | 0.767 | 6.35% | 69.22% | 38.72% |
| CF1 | 10 | 52.40% | 0.657 | 9.81% | 69.36% | 40.51% | 0.711 | 20.33% | 55.25% | 36.16% |
| C2-DTLZ2, r=0.2 | 4 | 13.04% | 0.587 | 5.65% | 66.03% | 35.84% | 0.776 | 5.27% | 56.60% | 31.06% |
| C2-DTLZ2, r=0.2 | 6 | 2.81% | 0.500 | 0.30% | 92.35% | 46.33% | 0.569 | 0.00% | 100.00% | 50.00% |
| MW7 | 4 | 4.37% | 0.456 | 0.59% | 69.19% | 35.56% | 0.856 | 1.00% | 78.69% | 39.98% |
| MW7 | 6 | 0.64% | 0.463 | 0.25% | 74.31% | 37.30% | 0.896 | 0.21% | 81.56% | 40.88% |

**Table 1.** Median metrics across five optimization seeds, evaluated on
262,144 independent Latin-hypercube probes per problem. FPR is the
false-feasible rate and FNR is the false-infeasible rate at
\(p_i\geq0.5\). Source: `dimension_trend_problem_method_medians.csv`,
calculated by `summarize_dimension_trend_20260726.m` from
`field_metrics.csv`.

## Paired dimension changes

| Family | Field | Dimension pair | Median balanced-error change | Seeds with higher error | Median AUC change |
|---|---|---:|---:|---:|---:|
| CF1 | Clipped GP mean | 4 to 10 | +8.88 points | 5/5 | -0.130 |
| CF1 | Offline RF proxy | 4 to 10 | -1.12 points | 2/5 | -0.060 |
| C2-DTLZ2, r=0.2 | Clipped GP mean | 4 to 6 | +8.60 points | 5/5 | -0.087 |
| C2-DTLZ2, r=0.2 | Offline RF proxy | 4 to 6 | +16.07 points | 5/5 | -0.161 |
| MW7 | Clipped GP mean | 4 to 6 | +3.84 points | 4/5 | +0.042 |
| MW7 | Offline RF proxy | 4 to 6 | +0.90 points | 3/5 | +0.063 |

**Table 2.** Paired high-dimension-minus-low-dimension changes using the
same replicate index and stable family-level probe/RF seeds. Source:
`dimension_trend_paired_summary.csv`, calculated from
`paired_aggregate_summary.csv`.

## Interpretation

Observed:

- The clipped GP mean worsened in balanced error for all CF1 and C2-DTLZ2
  seed pairs and for four of five MW7 pairs.
- The GP false-feasible rate did not generally increase. In each family it
  was unchanged or lower at the higher dimension, while the
  false-infeasible rate increased.
- The RF proxy showed a different CF1 trade-off and improved median
  balanced error slightly, despite a lower AUC.
- On rare-feasible C2-DTLZ2-D6, 3/5 RF runs predicted no feasible probes;
  the median FPR was 0 and median FNR was 1. This is not a low-error field.

Interpretation:

- Fixed-budget sparse coverage is consistent with the GP result, but a
  single scalar “false rate” obscures whether the field is optimistic or
  conservative.
- C2-DTLZ2 and MW7 cannot isolate dimension because their feasible volumes
  fall sharply with dimension. Their results are stress-test evidence.
- Similar CF1 prevalence makes its GP contrast more informative, but it
  remains a five-seed, one-family observation rather than a universal law.
- Domain error can decrease when feasible volume becomes very small, even
  while feasible-class recovery collapses. Balanced error, FPR, FNR, AUC,
  and balanced Brier should therefore be reported together.

## Verification and limitations

- Thirty-five cTSEMO trajectories completed with 20 initial and 130
  sequential evaluations each.
- All 24 independent validation checks passed, including confusion-count
  identities, exact benchmark-label reproduction, exact GP interpolation
  of all observed 0/1 labels, prediction bounds, and artifact existence.
- The campaign used five seeds. No statistical-significance claim is made.
- The RF proxy was fitted offline to final data selected by the GP-driven
  optimizer. It is a formulation sensitivity check, not an online RF
  optimizer comparison.
- The rank-plane figures are score-order visualizations, not geometric
  projections of the original design spaces.
- A 70-file source manifest was sealed with SHA-256. The exact manifest
  digest is stored in `source_manifest_summary.json`.

Validation sources: `validation_checks.csv`,
`VALIDATION_SUMMARY.txt`, `source_manifest.csv`, and
`source_manifest_summary.json`.

**Figure 1.** Paired FPR, FNR, balanced error, and ROC AUC for the clipped
GP mean and offline RF proxy. Thin lines represent seeds; thick lines
represent medians. Welded beam is an unpaired D4 reference. Source:
`figures/paired_dimension_gp_rf_metrics.png`, generated by
`plot_matched_dimension_pof_study_20260726.m` from `field_metrics.csv`.

**Figure 2.** Median and seed-level diagnostics across all seven problems.
Source: `figures/all_problem_gp_rf_metrics.png`, generated from
`field_metrics.csv`.

**Figures 3-6.** Representative D4 objective-space evidence and
ranked-score/truth/confusion diagnostics for welded beam, CF1,
C2-DTLZ2, and MW7. Sources: the four
`figures/*_pf_gp_rf_rank_truth_confusion.png` files, their selected
`result.mat` files, shared probe MAT files, and saved prediction MAT files.
