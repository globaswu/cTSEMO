# Changelog

All notable changes to cTSEMO are documented in this file.

## [0.2.0] - 2026-08-24

### Public reproduction release

- Curated the final manuscript evidence into stable, timestamp-free reader
  paths and excluded provisional, duplicate, and dense regenerable outputs.
- Added the current two-dimensional, GA-primary/challenger, matched-dimension,
  and hull-coverage reproduction workflows.
- Added a manuscript-to-artifact map, AI-agent instructions, environment
  record, SHA-256 artifact index, and clean-clone validation commands.
- Restored public benchmark provenance, corrected citation and licensing
  metadata, and removed workstation-path assumptions from reader workflows.

### Changed

- Replaced default finite-primary selection with bounded genetic-algorithm
  maximization of the scalar cTSEMO acquisition.
- Retained the deterministic Latin-hypercube/corner primary design as the GA
  seed and acquisition-reference set.
- Kept an independently seeded Latin-hypercube challenger as a coverage check;
  the final primary and challenger proposals are compared using the same
  Thompson draws, PoF, masks, and frozen acquisition background.
- Separated ordinary GA-primary/challenger arbitration from Phase-I and
  low-acquisition recovery policies.
- Added primary-search diagnostics, deterministic random-stream separation,
  an explicit finite-pool ablation/failure policy, and regression tests for
  bounds, seed non-regression, reproducibility, and end-to-end arbitration.

### Verification

- The complete MATLAB R2025b repository suite passed 105 of 105 tests on
  2026-08-09; the eight changed MATLAB files produced no Code Analyzer
  findings. See `src/tests/TEST_SUMMARY.md` and `test-results.xml`.

## [0.1.0] - 2026-07-24

Initial research release.

### Added

- Sequential constrained extension of Bradford TSEMO for exactly two
  minimization objectives.
- One aggregate binary feasibility label per evaluated design.
- Mean-only, zero-noise Gaussian-process feasibility interpolation using
  adjustable raw targets; defaults are \(z_-= -0.25\) and \(z_+=1.25\).
- Clipping of the raw feasibility mean to \([0,1]\) only after interpolation.
- Locally variable length-scale option with a stationary fallback.
- Objective Thompson draws and sampled HVI.
- Factorized main acquisition using the clipped field and bounded
  anti-clustering masks.
- Deterministic finite primary candidate pool using Latin-hypercube points and
  optional hyperrectangle corners.
- Separately seeded finite challenger pool evaluated with the same main
  acquisition.
- Objective-independent maximin feasibility discovery when no feasible
  initial observation exists.
- Explicit low-acquisition, nonfinite-acquisition, and duplicate-avoidance
  recovery paths.
- Explicit label-transport validation for logical aggregate labels,
  continuous inequality vectors, and numeric binary encodings.
- Per-iteration selection-source and acquisition-component diagnostics.
- Bradford source-provenance snapshot and BSD attribution.

### Deliberately excluded

- vMF-Wendland feasibility fields.
- Thompson sampling of a feasibility residual.
- Claims that the clipped field is a calibrated probability.
- Batch selection and problems with more or fewer than two objectives.
- DIRECT, NGPM, and MEX dependency trees from the upstream Bradford
  repository.
- Continuous or local acquisition-function optimization and refinement.

### Known limitations

- This is an initial research release, not a claim of solver superiority.
- The verified benchmark scope is limited to the artifacts included with this
  release; missing artifacts are not implied results.
- Aggregate binary labels discard violation magnitude and per-constraint
  structure.
- Exact interpolation assumes deterministic, noncontradictory labels and can
  be sensitive to near-duplicate sites.
- Clipping creates saturated regions and does not provide probability
  calibration.
- Local length-scale adaptation can smooth undiscovered feasible pockets and
  requires sensitivity and ablation checks.
- Anti-clustering masks and fallback rules are safeguards whose effect can
  depend on the candidate set.
- Candidate selection is limited by the resolution of the finite primary and
  challenger pools.
- Disabling the optional low-acquisition fallback does not disable Phase-I,
  nonfinite-search, duplicate-exclusion, or pool-regeneration safeguards.
- Existing external welded-beam comparisons use unmatched initial designs and
  richer continuous-constraint information for most competitors; they are
  exploratory rather than a controlled ranking.
- MATLAB R2025b is the development and verification environment. The minimum
  compatible MATLAB release is not established.
