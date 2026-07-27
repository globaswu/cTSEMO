# Matched-dimension PoF study

This directory contains the configurable campaign used to examine
feasibility-field diagnostics across matched benchmark families and
dimensions.

The full manuscript configuration is launched with:

```matlab
setup_ctsemo
[runs, metrics, aggregate, paired, studyDirectory] = launch_full_study;
```

The default full campaign contains seven benchmark instances, five
replicates per instance, and 150 evaluations per trajectory. It therefore
schedules 35 trajectories and 5,250 benchmark evaluations. The independently
generated probe sets and offline random-forest calculations add diagnostic
cost but no optimizer evaluations.

After the campaign completes:

```matlab
checks = validate_matched_dimension_pof_study(studyDirectory);
artifacts = plot_matched_dimension_pof_study(studyDirectory);
manifest = plot_manuscript_dimension_figures(studyDirectory);
summaryFiles = summarize_dimension_trend(studyDirectory);
sourceSummary = seal_dimension_study_sources(studyDirectory);
```

The random-forest field is fitted offline to the final GP-guided data. It is
a fixed-data diagnostic, not an online optimizer-policy comparison.
