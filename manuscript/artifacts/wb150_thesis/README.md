# WB150 thesis reconstruction

This bundle reproduces the thesis-specific final Thompson-draw diagnostics for
welded-beam replicate 2. Its computational source is the sanitized retained
record at:

`manuscript/artifacts/ga_primary_dimension/runs/WELDEDBEAM_rep02/result.mat`

## Run

```matlab
setup_ctsemo;
addpath(fullfile("manuscript", "artifacts", "wb150_thesis"));
outputs = generate_wb150_thesis_artifacts;
```

The default output root is `generated/wb150_thesis/`. The command:

- reconstructs the final objective Thompson draws from evaluations 1-149;
- verifies the selected draw, sampled HVI, scaling, and reference point against
  the stored iteration-130 record;
- regenerates four 121-station by 2,048-sample conditional reductions;
- regenerates all six 25 by 25 pairwise slices;
- writes the selected-iteration evidence row; and
- exports 130 individual A4 Pareto-evolution frames, with `page_130.pdf` as the
  thesis final-frame authority.

The committed CSVs are byte-identical to a clean rerun. The committed PDFs are
included for one-click inspection; PDF container metadata can differ between
runs. The 7.2 MB conditional workspace and the 130 generated frame files are
regenerable and therefore omitted.

These figures describe one archived Thompson realization and one nuisance
design. They are not posterior intervals and do not quantify repeated-draw
sensitivity.

