# Instructions for coding agents

## Repository boundary

Work only inside this repository. Do not import files from sibling thesis,
lattice-paper, or private development workspaces. If a required source is
missing, report it instead of searching unrelated personal folders.

## Start every technical task

1. Read `README.md`, `docs/REPRODUCING.md`, and the nearest directory README.
2. Run `setup_ctsemo` before MATLAB work.
3. Treat `src/cTSEMO.m` and `src/cTSEMOOptions.m` as the public interface.
4. Keep at most one user-visible MATLAB instance open.

## Scientific invariants

- The optimizer receives two finite objective values and one aggregate binary
  feasibility label at each evaluation.
- The feasibility field `p_i` is an operational clipped GP-mean score, not a
  calibrated Bernoulli posterior.
- The default ordinary primary search uses `ga`; the independent challenger
  evaluates the same frozen acquisition.
- Phase-I feasibility discovery and recovery selections must remain distinct
  from ordinary primary/challenger arbitration in code and reporting.
- Do not use offline benchmark truth, validation probes, or retained results
  to influence candidate selection.

## Reproducibility rules

- Preserve fixed seeds, budgets, problem identifiers, and source manifests.
- Use repository-relative paths and `fullfile`; never commit workstation paths.
- Reader-facing file and directory names must be stable and timestamp-free.
  Original run identifiers may remain inside manifests as provenance.
- Do not commit caches, checkpoints, dense regenerable probes, or provisional
  comparison campaigns.
- After changing retained evidence, run
  `manuscript/artifacts/update_artifact_manifest.m`.

## Required checks before a commit

```matlab
setup_ctsemo;
results = run_repository_tests;
assertSuccess(results);
```

Also run one short GA-primary smoke case, inspect `git diff --cached`, scan for
absolute paths and credentials, and verify that no file exceeds GitHub's
ordinary file-size limit. Do not launch a full campaign unless the user asks.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify_public_release.ps1
```

The PowerShell check covers text and manifest integrity. The MATLAB
`ThesisArtifactTest` additionally loads retained MAT records and recursively
checks their string fields for private machine paths.
