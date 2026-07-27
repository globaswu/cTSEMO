# cTSEMO notice

cTSEMO version 0.1.0 is an initial research release for sequential constrained
two-objective Bayesian optimization with aggregate binary feasibility labels.

The implementation is a derivative extension of the MATLAB TSEMO algorithm by
Eric Bradford, Artur M. Schweidtmann, and Alexei A. Lapkin. The original
authors do not endorse this derivative release and are not responsible for its
modifications, benchmark results, or conclusions.

The unmodified provenance snapshot in `vendor/bradford-tsemo/` is pinned to:

- upstream repository: <https://github.com/Eric-Bradford/TS-EMO>
- commit: `9ec2aa2f54d1232f80d37494ac067f2ebc112688`
- commit date: 2020-06-19
- upstream license: BSD 2-Clause

The original copyright notice and complete license are preserved in
`vendor/bradford-tsemo/LICENSE`.

The cTSEMO feasibility field is a clipped zero-noise Gaussian-process
regression mean fitted to artificial targets. It is an operational score and
is not, without separate calibration evidence, a posterior probability of
feasibility.

The vMF-Wendland feasibility formulation used in earlier research prototypes
is not part of this release.
