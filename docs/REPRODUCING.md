# Reproducing the cTSEMO manuscript results

Run all commands from the repository root. The commands below separate quick
verification, plot-only reconstruction, and full optimization reruns.

## 1. Verify the installation

```matlab
root = setup_ctsemo;
assert(strcmp(which("cTSEMO"), fullfile(root, "src", "cTSEMO.m")));
results = run_repository_tests;
assertSuccess(results);
```

Short integration checks for the dependency-light pool path and the shipped
GA path are:

```matlab
poolOptions = struct( ...
    "InitialPointCount", 4, ...
    "SequentialEvaluations", 1, ...
    "SolverOptions", struct( ...
        "primarySearch", struct("method", "pool"), ...
        "logging", struct("level", "none", "checkpoint", false, ...
            "saveEveryIteration", false)));
poolSmoke = runSmokeBenchmarks("COSSIN1", poolOptions);
assert(strcmp(poolSmoke.Status, "passed"));

gaOptions = poolOptions;
gaOptions.SolverOptions = rmfield( ...
    gaOptions.SolverOptions, "primarySearch");
gaSmoke = runSmokeBenchmarks("COSSIN1", gaOptions);
assert(strcmp(gaSmoke.Status, "passed"));
```

## 2. Regenerate figures without rerunning optimization

### Introduction feasibility-field comparison

```matlab
setup_ctsemo;
run_introduction_pof_comparison;
```

### Two-dimensional campaign

```matlab
setup_ctsemo;
reproduce_two_dimensional_pof_results("ReuseResults", true);
```

Then regenerate the two Python-composited figures:

```powershell
python studies/two_dimensional_pof/make_cossin2_acquisition_decomposition.py
python studies/two_dimensional_pof/build_shared_classification_legend.py
```

### Higher-dimensional summaries and hypervolume histories

```matlab
setup_ctsemo;
run("manuscript/artifacts/ga_primary_dimension/" + ...
    "reproduce_highdimensional_results.m");
```

This command loads the 35 retained `result.mat` files and the recorded fixed
normalization. Dense probe arrays are unnecessary for these reconstructions;
their reported reductions are retained in `field_metrics.csv`.

### Convex-hull diagnostic

```powershell
python studies/hull_coverage/plot_dimension_hull_coverage.py
```

## 3. Rerun the optimization experiments

### Four two-dimensional cases

```matlab
setup_ctsemo;
reproduce_two_dimensional_pof_results;
```

### Five-case GA-primary/challenger audit

```matlab
setup_ctsemo;
ids = ["COSSIN1", "COSSIN2", "BNH", "SRN", "C2DTLZ2"];
runOptions = struct( ...
    "OutputRoot", fullfile(pwd, "tmp", "challenger_rerun"), ...
    "ContinueOnFailure", false);
[summary, campaignDirectory] = runReleaseBenchmarks(ids, runOptions);
```

### Matched-dimension campaign

```matlab
setup_ctsemo;
[runs, metrics, aggregate, paired, studyDirectory] = launch_full_study;
checks = validate_matched_dimension_pof_study(studyDirectory);
figures = plot_matched_dimension_pof_study(studyDirectory);
sourceSummary = seal_dimension_study_sources(studyDirectory);
```

The matched-dimension command performs 35 trajectories of 150 evaluations and
is the longest supplied workflow. Run it only when a full independent rerun is
intended.

## 4. Verify the evidence index

```matlab
setup_ctsemo;
manifest = update_artifact_manifest;
assert(all(strlength(manifest.Sha256) == 64));
```

The execution-time source manifests stored inside campaign directories are
historical seals of the code used for those runs. `artifact_manifest.csv` is
the current index of the compact public evidence bundle.
