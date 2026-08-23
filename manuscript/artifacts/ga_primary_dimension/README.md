# GA-primary matched-dimension campaign

This directory contains the current five-replicate, 150-evaluation campaign
for welded beam, CF1, C2-DTLZ2, and MW7.

- `runs/<case>/result.mat` contains the 35 complete optimization trajectories.
- `field_metrics.csv` and `paired_aggregate_summary.csv` contain the retained
  independent-probe feasibility diagnostics.
- `ga_primary_highdim_per_run.csv` and
  `ga_primary_highdim_summary.csv` contain the optimization and selection
  outcomes.
- `ga_primary_highdim_normalization.csv` records the fixed post-hoc
  normalization used for the within-problem hypervolume histories.
- `reproduce_highdimensional_results.m` reconstructs the reported summaries
  and histories without the omitted dense probe arrays.
- `validation_checks.csv`, `study_manifest.json`, and `source_manifest.csv`
  preserve protocol and source provenance.

`source_manifest.csv` is an execution-time historical checksum record. Some
listed dense probe or packaging files are deliberately absent from the compact
release; the current public source is identified by the Git tag.

Dense probe coordinates and prediction arrays are omitted because their
reported reductions are retained in `field_metrics.csv`; the deterministic
study scripts and seeds can regenerate them. The obsolete finite-pool campaign
is not included.
