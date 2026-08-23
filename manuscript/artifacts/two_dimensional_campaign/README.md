# Two-dimensional manuscript campaign

This directory contains the compact numerical authority for the deterministic
COSSIN1, COSSIN2, BNH, and SRN runs reported in the manuscript.

## Retained files

- `runs/*_result.mat`: complete cTSEMO trajectories for exact plot-only
  reconstruction;
- `campaign_summary.csv`: one row per optimization trajectory;
- `pof_metrics.csv`: initial and final independent-grid diagnostics;
- `cossin_learning_metrics.csv`: intermediate COSSIN reconstructions;
- `pof_field_data.mat`: full-precision final fields and COSSIN histories;
- `run_configuration.csv` and `campaign_manifest.json`: fixed budgets, seeds,
  and solver settings;
- `source_manifest.*`: execution-time source hashes; and
- `figures/`: manuscript figures and the intermediate raster needed by the
  shared-legend compositor.

The four large pointwise grid CSV files are omitted because their full-
precision content is retained in `pof_field_data.mat`. They can be regenerated
from the run records.

The source manifest is a historical checksum record from campaign execution;
the current public source is identified by the Git tag and may omit unrelated
packaging files listed by that historical inventory.

From the repository root, regenerate the MATLAB figures without rerunning the
optimization:

```matlab
setup_ctsemo;
reproduce_two_dimensional_pof_results("ReuseResults", true);
```

The acquisition decomposition and shared classification legend use the Python
commands documented in `docs/REPRODUCING.md`.
