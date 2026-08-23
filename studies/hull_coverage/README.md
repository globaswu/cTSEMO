# Convex-hull coverage diagnostic

Run from the repository root:

```powershell
python studies/hull_coverage/plot_dimension_hull_coverage.py
```

The script reads the two CSV files in `data/` and writes
`manuscript/artifacts/hull_coverage/dimension_hull_coverage.pdf` plus a PNG
preview. The calculations are geometric diagnostics for one retained
fixed-seed maximin-Latin-hypercube sequence; they are not an optimizer budget
rule.
