# cTSEMO

cTSEMO is a MATLAB implementation of sequential, constrained,
two-objective Bayesian optimization when every evaluation returns two finite
objective values and one aggregate feasible-or-violating label. It extends the
TSEMO workflow with a clipped Gaussian-process-mean feasibility score, bounded
genetic-algorithm acquisition search, an independent same-acquisition
challenger, anti-clustering masks, and explicit discovery and recovery states.

This is the standalone code and numerical-reproduction repository for the
cTSEMO manuscript and the analytical evidence used in Chapter 3 of the
author's doctoral thesis. It does not contain the thesis document or the
lattice-wing simulation workspace.

- Release: `v0.2.1` (the cTSEMO 0.2.0 algorithm with publication-hygiene and
  thesis-evidence additions)
- Thesis companion release:
  <https://github.com/globaswu/aeroverify-thesis-artifacts/releases/tag/thesis-v1.0.2>

## Quick start

Clone the repository, open MATLAB in its root directory, and run:

```matlab
setup_ctsemo;

options = cTSEMOOptions();
result = cTSEMO(f, g, X0, Y0, C0, lb, ub, options);
```

The inputs are documented in [`docs/ALGORITHM.md`](docs/ALGORITHM.md). A short
integration run using a packaged benchmark is:

```matlab
setup_ctsemo;
smoke = runSmokeBenchmarks("COSSIN1");
assert(strcmp(smoke.Status, "passed"));
```

Run the full regression suite with:

```matlab
results = run_repository_tests;
assertSuccess(results);
```

Maintainers can refresh the committed JUnit and human-readable evidence with
`run_release_tests`.

## Reproduce the manuscript results

Three levels are supported:

1. **Audit the published values without rerunning optimization.** Compact
   CSV, JSON, MAT, and PDF records are under `manuscript/artifacts/`.
2. **Regenerate plots from retained run records.** The required MATLAB and
   Python commands are listed in [`docs/REPRODUCING.md`](docs/REPRODUCING.md).
3. **Rerun the optimization campaigns.** Fixed seeds, budgets, benchmark
   definitions, solver settings, and validation commands are included in the
   study scripts.

[`docs/RESULTS_MAP.md`](docs/RESULTS_MAP.md) maps every numerical manuscript
figure and table to its source data and generating program. The repository
retains the 35 higher-dimensional optimization trajectories, the COSSIN2
full-iteration record needed for acquisition decomposition, and compact
field/selection summaries. It also retains a path-free 35-run finite-primary
export for the matched ablation and a repository-relative WB150 thesis
reconstruction. Large deterministic probe arrays, raw private-path archives,
and regenerable workspaces remain omitted.

## Repository layout

| Path | Purpose |
|---|---|
| `src/` | Public solver, core package, benchmarks, diagnostics, examples, and tests |
| `studies/` | Executable Introduction, two-dimensional, dimensional, and hull studies |
| `manuscript/artifacts/` | Curated numerical authority for the reported results |
| `manuscript/artifacts/finite_primary_ablation/` | Path-free Table 3.6 comparison records and recomputation |
| `manuscript/artifacts/wb150_thesis/` | Thesis-specific final-HVI and Pareto-evolution reconstruction |
| `manuscript/paper/main.tex` | Manuscript source linked directly to the curated figures |
| `docs/` | Algorithm, environment, reproduction, and result-provenance guides |
| `AGENTS.md` | Operating instructions for coding agents working in this repository |

The parent research workspace is intentionally excluded. Public source paths
are repository-relative and reader-facing directory names contain no run
timestamps. Original run identifiers remain inside manifests where they are
part of the provenance record.

## Verified environment

The release was verified with MATLAB R2025b Update 5. The ordinary default
GA-primary path requires Optimization Toolbox and Global Optimization
Toolbox. The Introduction PoF comparison additionally requires Statistics and
Machine Learning Toolbox. Optional Python figure post-processing was verified
with the versions recorded in [`requirements-lock.txt`](requirements-lock.txt).
The minimum compatible MATLAB release has not been established.

## Scientific scope

The field denoted by `p_i` is an operational feasibility score derived from
aggregate binary labels. It is not presented as a calibrated Bernoulli
posterior. The retained campaigns support implementation and diagnostic
claims under the reported seeds and budgets; they do not establish global
optimality or superiority over external constrained optimizers.

## Citation, license, and provenance

Citation metadata are in [`CITATION.cff`](CITATION.cff). Repository-authored
code, scripts, documentation, and retained numerical records are released
under the BSD 2-Clause License unless a file states otherwise. Bradford TSEMO
provenance, benchmark sources, and third-party notices are documented in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and
[`NOTICE.md`](NOTICE.md).
