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
- `synthetic_constraint_margins.csv`, containing the pointwise
  \(g_1(\mathbf{x}_j)\), \(g_2(\mathbf{x}_j)\), individual \(\Phi\) factors,
  and product-PoF values;
- `pof_comparison_data.mat`; and
- `SUMMARY.txt`.

The fixed synthetic design contains 40 observations. For the illustrative
constraint-wise GP product, reproducible random margin magnitudes are assigned
at every sampled design while preserving the sign of each analytic constraint
outcome and, therefore, every aggregate feasible or violating label. The CSV
records both the analytic margins used to determine those signs and the
synthetic margins supplied to the two GPs. This continuous-margin product is
information-richer than the other fitted methods, which receive only the
aggregate label. The comparison is descriptive and does not establish
optimizer-level superiority.
