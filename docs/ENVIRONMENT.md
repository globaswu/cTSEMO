# Verified environment and dependencies

## MATLAB

The release was verified with MATLAB R2025b Update 5 on Windows 11.

| Workflow | Required products |
|---|---|
| Core solver with `primarySearch.method="pool"` | MATLAB |
| Default GA-primary solver and full tests | Optimization Toolbox; Global Optimization Toolbox |
| Introduction PoF comparison | Statistics and Machine Learning Toolbox |
| `useParallel=true` | Parallel Computing Toolbox |
| SHA-256 source and artifact manifests | MATLAB JVM |

Dependency analysis indicates that the core solver does not require
Statistics and Machine Learning Toolbox. The minimum compatible MATLAB release
has not been established; API inspection suggests R2022a or newer, but that is
not a tested compatibility claim.

The vendored Bradford files are provenance snapshots rather than a standalone
entry point. Their omitted DIRECT, NSGA-II, and MEX dependencies are not needed
by cTSEMO.

## Python

Python is used only for three manuscript post-processors. The tested versions
are recorded in `requirements-lock.txt`; install them with:

```powershell
py -3 -m pip install -r requirements.txt
```

The MATLAB solver and regression suite do not require Python.
