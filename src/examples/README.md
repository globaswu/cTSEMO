# Examples

The smoke runner uses the public API and source-traced benchmark definitions.
Run it from the repository root after setup:

```matlab
setup_ctsemo;
results = runSmokeBenchmarks();
```

To exercise the fallback state in which the initial BNH design contains no
feasible observation:

```matlab
runOptions = struct( ...
    "UseAllInfeasibleStress", true, ...
    "StressProblemIds", "BNH", ...
    "SequentialEvaluations", 2);
results = runSmokeBenchmarks("BNH", runOptions);
```

`initialDesign` constructs this diagnostic case by filtering deterministic
Latin-hypercube batches until all retained points are violating. It is not an
ordinary random initialization and must not be used as if it were a matched
performance benchmark.

The default sequential budget is intentionally tiny. A successful smoke run
checks integration and fallback liveness; it does not establish optimizer
effectiveness.
