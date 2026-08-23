# Manuscript result map

This table identifies the minimum retained authority and executable route for
the numerical material in `manuscript/paper/main.tex`.

| Manuscript item | Numerical authority | Reproduction route |
|---|---|---|
| Figure 1, PoF atlas | `manuscript/introduction_pof_comparison/output/pof_field_metrics.csv`, `synthetic_constraint_margins.csv` | `run_introduction_pof_comparison.m` |
| Figure 2, GPC versus clipped GP mean | Same Introduction output directory | `run_introduction_pof_comparison.m` |
| Table 5, primary/challenger audit | `manuscript/artifacts/ga_primary_challenger/ga_primary_challenger_summary.csv`, `ga_primary_search_audit.csv` | `runReleaseBenchmarks.m` for a fresh campaign |
| Table 6 and Figure 4 | `two_dimensional_campaign/campaign_summary.csv`, `pof_metrics.csv`, `pof_field_data.mat` | `reproduce_two_dimensional_pof_results.m` |
| Figure 5 | `two_dimensional_campaign/runs/COSSIN2_result.mat` | `make_cossin2_acquisition_decomposition.py` |
| Figures 6-8 | `pof_field_data.mat`, `cossin_learning_metrics.csv`, `pof_metrics.csv` | Two-dimensional MATLAB study and shared-legend Python script |
| Table 7 and Figures 9-10 | `ga_primary_dimension/field_metrics.csv`, `paired_aggregate_summary.csv` | `plot_matched_dimension_pof_study.m` for a fresh study |
| Table 8 | `ga_primary_highdim_summary.csv`, `ga_primary_highdim_per_run.csv` | `reproduce_highdimensional_results.m` |
| Figures 11-12 | Thirty-five files under `ga_primary_dimension/runs/` and `ga_primary_highdim_normalization.csv` | `reproduce_highdimensional_results.m` |
| Figure 13 | `studies/hull_coverage/data/*.csv` | `plot_dimension_hull_coverage.py` |
| Test claims | `manuscript/artifacts/tests/TEST_SUMMARY.md`, `test-results.xml` | `run_repository_tests.m` |

Tables describing equations, defaults, and benchmark definitions are sourced
directly from `src/+ctsemo/`, `src/cTSEMOOptions.m`, and
`src/benchmarks/getBenchmarkProblem.m`; they are not independent numerical
experiments.
