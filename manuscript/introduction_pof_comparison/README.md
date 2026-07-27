# Introduction PoF comparison

`run_introduction_pof_comparison.m` generates both feasibility-field figures
used in the manuscript Introduction:

1. the six-method reference atlas; and
2. the Bernoulli GP-classification versus cTSEMO clipped GP-mean comparison.

From the repository root, run:

```matlab
setup_ctsemo
run_introduction_pof_comparison
```

Outputs are written to `output/`:

- `table1_pof_atlas.png` and `.pdf`;
- `gpc_ctsemo_pof_comparison.png` and `.pdf`;
- `pof_field_metrics.csv`;
- `pof_comparison_data.mat`; and
- `SUMMARY.txt`.

The fixed synthetic design contains 40 observations. The conventional
constraint-wise GP product alone receives the two continuous constraint
margins; every other fitted method receives only the aggregate feasible or
violating label. The comparison is descriptive and does not establish
optimizer-level superiority.
