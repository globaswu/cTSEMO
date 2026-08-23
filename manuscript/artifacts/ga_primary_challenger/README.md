# GA-primary and challenger audit

These compact records support the manuscript's single-seed audit of ordinary
GA-primary versus independent LHS-challenger selection.

- `ga_primary_challenger_summary.csv` contains the per-problem source counts.
- `ga_primary_search_audit.csv` records completed GA searches and improvements
  over the best primary seed.
- `cases/*/evaluations.csv` and `selection_history.csv` retain every evaluated
  point and selection decision.
- `cases/*/initial_design.csv` and `options.json` preserve the exact inputs.
- `release_source_manifest.*` is the historical execution-time checksum
  record. It can list non-algorithm packaging files omitted from the compact
  public tree; the current release source is identified by the Git tag.

The discarded finite-pool comparison and per-iteration diagnostic MAT files
are not part of the manuscript evidence and are intentionally excluded.
