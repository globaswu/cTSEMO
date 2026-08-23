# Development and release checks

Use a feature branch and stage files explicitly. Avoid `git add .` in a
workspace that also contains generated campaigns.

```powershell
git status --short
git diff
git add README.md docs src studies manuscript
git diff --cached --check
git status --short
```

Before committing:

1. run `run_repository_tests` and both one-iteration smoke paths documented in
   `REPRODUCING.md`;
2. run MATLAB Code Analyzer on changed `.m` files;
3. update `manuscript/artifacts/artifact_manifest.csv`;
4. scan tracked text files for absolute workstation paths, credentials,
   caches, and generated timestamps in reader-facing names;
5. verify the manuscript compiles from `manuscript/paper/main.tex`; and
6. confirm that every third-party file is covered by
   `THIRD_PARTY_NOTICES.md`.

Release tags use semantic versioning. A release is created only from the
default branch after a clean-clone verification.
