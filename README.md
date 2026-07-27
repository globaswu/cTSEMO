# cTSEMO MATLAB companion repository

This repository collects the MATLAB source used for the cTSEMO algorithm,
its benchmark and diagnostic utilities, and the manuscript-specific
feasibility-field figures. It is organized for retrieval by readers: source
file and directory names describe their purpose and do not contain
development timestamps.

The repository is a clean copy. The dated development folders, intermediate
experiments, and run snapshots remain in the private working archive and are
not required to navigate this version.

## Quick start

Open MATLAB in this repository and run:

```matlab
setup_ctsemo
```

The public optimization interface is:

```matlab
options = cTSEMOOptions();
result = cTSEMO(f, g, X0, Y0, C0, lb, ub, options);
```

To reproduce the Introduction feasibility-field figures:

```matlab
run_introduction_pof_comparison
```

The generated figures, metrics, and summary are written to
`manuscript/introduction_pof_comparison/output/`.

To run the source tests:

```matlab
results = run_repository_tests;
```

## Repository structure

| Path | Contents |
|---|---|
| `src/` | cTSEMO public interface, implementation, benchmarks, diagnostics, examples, and tests |
| `src/+ctsemo/` | Core package functions |
| `manuscript/introduction_pof_comparison/` | Code for the comparative PoF atlas and proposed-method comparison |
| `studies/dimension_matched_pof/` | Matched-dimension feasibility-field campaign and plotting utilities |
| `CODE_INDEX.md` | Manuscript and algorithm component-to-file index |

## MATLAB environment

The recorded development and verification environment is MATLAB R2025b. The
minimum compatible MATLAB release was not established. The Introduction
comparison uses Statistics and Machine Learning Toolbox functions including
`lhsdesign`, `fitcsvm`, `fitPosterior`, `fitcensemble`, and `fitcnet`.

Run the bundled tests in the local MATLAB environment before relying on new
results.

## Naming and provenance

Development timestamps were removed from source file and directory names in
this reader copy. Fixed random seeds are retained inside scripts because they
are part of the reproducibility record. Newly generated run directories may
contain run identifiers or creation times so that independent campaigns do
not overwrite one another.

The conventional constraint-wise Gaussian-process product in the
Introduction comparison receives continuous constraint margins. All other
fitted fields in that comparison receive only the common aggregate binary
labels. The resulting visual comparison is therefore diagnostic and is not a
matched optimizer ranking.

## Citation and license

Software citation metadata are provided in `CITATION.cff`. New cTSEMO source
is distributed under the BSD 2-Clause License. The provenance copy of the
Bradford TSEMO source retains its own notice under
`src/vendor/bradford-tsemo/`.
