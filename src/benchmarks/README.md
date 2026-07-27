# Source-traced benchmark definitions

`getBenchmarkProblem.m` provides vectorized, two-objective minimization
definitions. Every problem exposes continuous constraint margins with the
convention `G <= 0`, a logical feasibility handle, a `0/1` feasibility-label
handle, and the legacy cTSEMO `-1/+1` binary-constraint handle.

| Identifier | Variables | Package-contained provenance |
|---|---:|---|
| `COSSIN1`, `COSSIN2` | 2 | `getBenchmarkProblem.m` |
| `BNH` (`BK2`) | 2 | `provenance/bradford-test-functions/ttbuk2.m`, `ttbukg2.m` |
| `SRN` (`BK1`) | 2 | `provenance/bradford-test-functions/ttbuk1.m`, `ttbukg1.m` |
| `WELDEDBEAM` | 4 | `provenance/bradford-test-functions/weldbeam.m`, `weldbeamconstr.m`; vectorized registry transcription |
| `C2DTLZ2` | 3 | `provenance/c2dtlz2_reference.m` |
| `C2DTLZ2_D4_R02` | 4 | `provenance/high-dimensional-benchmarks.md` |
| `C2DTLZ2_D6_R02` | 6 | `provenance/high-dimensional-benchmarks.md` |
| `OSY` | 6 | `provenance/high-dimensional-benchmarks.md` |
| `MW7_D4` | 4 | `provenance/high-dimensional-benchmarks.md` |
| `MW7_D6` | 6 | `provenance/high-dimensional-benchmarks.md` |
| `CF1_D4` | 4 | `provenance/high-dimensional-benchmarks.md` |
| `CF1_D10` | 10 | `provenance/high-dimensional-benchmarks.md` |

The SRN registry entry intentionally uses the standard quadratic circle
constraint and the `(x_2-1)^2` objective term from `ttbuk1.m`/`ttbukg1.m`.
An older generated audit script used fourth powers and shifted the first
objective; that variant is not reproduced.

No source-supported fixed hypervolume reference was found in these problem
definitions. Accordingly, each returned `hypervolumeReference` is empty. A
comparison study must declare and hold a common reference point fixed before
computing hypervolume.

`initialDesign.m` produces deterministic randomized-Latin-hypercube plus
all-corners designs without Statistics Toolbox. Under its scoped random
stream, each dimension draws one permutation of the `n` strata, then one
independent uniform within-stratum jitter for every row. Its `AllInfeasible`
option filters successive local LHS batches to test the solver's
no-feasible-point fallback. Such a stress design is diagnostic and must not
be described as an ordinary random initialization.

The lightweight runner is in `../examples/runSmokeBenchmarks.m`. Its default
budget is only a smoke check; it is not evidence of optimizer performance.

`runReleaseBenchmarks.m` defines the frozen, time-bounded release campaign.
Its default cases are COSSIN1 20+30, COSSIN2 20+60, BNH 10+30, an engineered
all-infeasible BNH 10+20 fallback stress case, corrected SRN 10+30, and
C2-DTLZ2 15+45. The welded-beam 20+130 case must be enabled explicitly.
Runtime settings are held at 1,024 primary candidates, 512 challenger
candidates, and 256 objective random Fourier features. COSSIN2 receives full
online logging; other cases receive summary logging. The campaign transports
only aggregate `0/1` labels through `problem.label01` and explicitly selects
`feasibility.inputEncoding="feasibleIsOne"`; continuous margins are retained
only as exact-truth diagnostic columns.

The higher-dimensional cases are not part of the frozen seven-case release
campaign. `runHighDimensionalChallengerStudy` runs a separate paired
engineering screen. It excludes all \(2^D\) corners from the deterministic
initial LHS and compares the legacy primary-only Pareto filter with the
complete-pool scoring policy on identical initial designs and solver seeds.
Its three-replicate default is diagnostic, not sufficient for a journal-level
optimizer-performance claim.

Each case directory preserves its manifest, exact MAT files, full-precision
numeric CSV files (`%.17g`), options, initial design, final result, component
timing, and selection history. `summarizeReleaseBenchmarks.m` reconstructs
case and campaign summaries without rerunning optimization. Its reported
hypervolume uses the solver-derived final-feasible reference point and is not
a matched cross-run hypervolume. Serialized campaign, case, option, and
canonical-result paths use `@CAMPAIGN_ROOT@` and `@CASE_ROOT@` tokens; absolute
paths are retained only in runtime-local variables.

## Campaign authority

Every new campaign writes:

- `release_source_manifest.csv`
- `release_source_manifest.sha256`
- `release_source_manifest.mat`
- `release_source_manifest.json`

The SHA-256 digest of `release_source_manifest.csv` is the campaign source
authority. It seals the public/core MATLAB implementation, documentation,
diagnostics, examples, benchmark and test source, package-contained benchmark
provenance, vendored source, and any test artifacts present at launch. It
does not claim a Git commit for this workspace.

The future post-fix campaign generated from the frozen release by
`runReleaseBenchmarks.m`, carrying this source seal and the final test
artifacts, is the official shipped-profile campaign. The existing
`benchmark-results/release_v0_1_0_20260724` directory is a higher-cost
sensitivity archive with different budgets and logging settings; it is not
the official release protocol and must not replace the post-fix campaign in
headline reporting.

`runWeldedBeamProfileSensitivity.m` is a separate WB150 computational
sensitivity study. It holds the official initial design, solver seed, and
20+130 budget fixed while comparing the shipped 1024/512/256 profile with a
2048/1024/1000 profile. Both profiles are separately rerun from the identical
saved initial design; the shipped-profile result is not reused from the
official campaign. Its source-sealed results must remain outside the
authoritative benchmark table and must not be interpreted as superiority
evidence.
