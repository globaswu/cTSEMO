# Manuscript reproducibility artifacts

This directory provides the compact source records cited by the cTSEMO
manuscript. The paper links to this index instead of printing internal file
and directory names in its prose and captions.

[`artifact_manifest.csv`](artifact_manifest.csv) is the machine-readable
registry of retained evidence files in this directory and in the Introduction
PoF reproduction directory. Its paths are relative to `manuscript`, and it
records file sizes, categories, intended roles, and drafting-time retention
status. Run
[`update_artifact_manifest.m`](update_artifact_manifest.m) after adding or
retiring an artifact. No drafting artifact should be deleted merely because it
is not used by the current manuscript revision; obsolete files will be
identified and reviewed together during the final cleanup.

Copied text records use `${PROJECT_ROOT}`, `${LEGACY_TSEMO_ROOT}`, and
`${MANUSCRIPT_ROOT}` in place of workstation-specific absolute roots. These
placeholders retain each original relative suffix; they do not imply that
omitted large derived arrays are stored in this compact bundle. Run
[`sanitize_artifact_paths.m`](sanitize_artifact_paths.m) before updating the
manifest whenever text evidence is added.

## Introduction PoF figures

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=globaswu/cTSEMO&file=manuscript/introduction_pof_comparison/reproduce_introduction_pof_figures.m)

The executable entry point
[`reproduce_introduction_pof_figures.m`](../introduction_pof_comparison/reproduce_introduction_pof_figures.m)
regenerates both Introduction PoF figures, checks all 40 pointwise records,
and displays the verified figures. The underlying script, generated figures,
pointwise synthetic margins, probability factors, and scalar diagnostics are
stored in [`introduction_pof_comparison`](../introduction_pof_comparison/).

## Release-integration campaign

[`release_campaign`](release_campaign/) contains the sealed campaign summary,
campaign and source manifests, and one final MATLAB run record for each of:

- COSSIN1;
- COSSIN2;
- BNH;
- the all-infeasible-initialization BNH stress case;
- SRN;
- C2-DTLZ2; and
- welded beam.

The corresponding execution and benchmark definitions are
[`runReleaseBenchmarks.m`](../../src/benchmarks/runReleaseBenchmarks.m),
[`summarizeReleaseBenchmarks.m`](../../src/benchmarks/summarizeReleaseBenchmarks.m),
and [`getBenchmarkProblem.m`](../../src/benchmarks/getBenchmarkProblem.m).

## Figure and table diagnostics

[`diagnostics`](diagnostics/) contains the compact campaign histories,
COSSIN2 independent-grid PoF records, welded-beam PoF metrics, and unmatched
competitor-source summaries used in the manuscript figures and tables. The
diagnostic implementation is under [`src/diagnostics`](../../src/diagnostics/).

The full derived welded-beam \(50^4\) raster matrix is not duplicated here.
Its final run record, scalar and reliability diagnostics, and raster summary
are included, and the raster can be recomputed with
[`computeSortedPofRaster4D.m`](../../src/diagnostics/computeSortedPofRaster4D.m).

## Fixed-budget dimension study

[`dimension_study`](dimension_study/) contains the compact final field
metrics, paired summaries, representative-run registry, validation records,
study manifest, and source manifest. The study and plotting implementation is
under [`studies/dimension_matched_pof`](../../studies/dimension_matched_pof/).
Large per-probe prediction arrays are derived artifacts and are not duplicated
in this compact repository bundle.

## Supporting verification records

- [`sensitivity`](sensitivity/) contains the matched welded-beam
  computational-profile sensitivity summary and its manifests.
- [`tests`](tests/) contains the human-readable and machine-readable release
  test summaries. The executable test classes are under
  [`src/tests`](../../src/tests/).
- [`competitors`](competitors/) contains the source index for the explicitly
  unmatched welded-beam competitor pilot.
- Shipped solver settings are defined in
  [`cTSEMOOptions.m`](../../src/cTSEMOOptions.m).

## Scope

These records support traceability of the reported calculations. The
single-seed release campaign is an integration test, not a statistically
matched solver ranking. The dimensional study contains five trajectories per
instance, while the large-grid PoF diagnostics use probe points rather than
independent optimization replicates.
