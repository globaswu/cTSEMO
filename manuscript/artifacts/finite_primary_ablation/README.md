# Matched finite-primary ablation

This directory supplies the path-free numerical authority for the thesis
comparison between the GA-primary cTSEMO release and 35 archived finite-primary
trajectories. The archived optimizer was not rerun for the thesis.

## Reproduce Table 3.6

From the repository root in MATLAB:

```matlab
setup_ctsemo;
run(fullfile("manuscript", "artifacts", "finite_primary_ablation", ...
    "reproduce_finite_primary_ablation.m"));
```

The script reads the 5,250 exported finite-primary evaluations and the 35
sanitized GA-primary result records. It verifies matched seeds, initial inputs,
initial objectives, initial labels, and common core options; recomputes both
hypervolume histories under the retained pooled normalization; and checks the
reconstructed tables against the committed authorities within `1e-9`.
Generated tables and figures are written below `generated/finite_primary_ablation/`.

## Files

| File | Purpose |
|---|---|
| `finite_primary_evaluations.csv` | 35 trajectories x 150 evaluated rows, with inputs, objectives, labels, selection states, and acquisition timing |
| `finite_primary_run_summary.csv` | path-free seeds, budgets, counts, and timing for the archived runs |
| `finite_primary_core_options.json` | common non-path solver options used by the finite-primary records |
| `comparison_normalization_reference.csv` | fixed pooled normalization and reference point for each problem |
| `paired_ga_vs_finite_pool_pf_comparison.csv` | 35 paired post-processing results |
| `problem_ga_vs_finite_pool_pf_comparison.csv` | seven thesis table rows before display rounding |
| `reproduce_finite_primary_ablation.m` | public recomputation and validation route |

The raw archived MAT files are deliberately excluded because they contain
machine-specific runtime metadata. The public CSV export retains every
evaluated design, objective, label, iteration source, state, and acquisition
time needed for the reported reduction. It does not establish optimizer
superiority: the seven problem-level effects are mixed.

