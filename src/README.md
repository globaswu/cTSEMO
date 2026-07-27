# cTSEMO

This directory is the source-only copy used by the manuscript companion
repository. Generated benchmark campaigns, test outputs, and diagnostic
artifacts are intentionally excluded; the bundled runners regenerate them.

cTSEMO is a minimal constrained, sequential, two-objective MATLAB extension of
the Thompson sampling efficient multiobjective optimization (TSEMO) algorithm
published by Bradford, Schweidtmann, and Lapkin. It is intended for expensive
black-box problems for which an evaluation returns two objective values and
one aggregate binary feasibility label.

This is version 0.1.0, the initial research release. The implementation is
provided for reproducible research and method development. Its verified scope
is deliberately narrow:

- exactly two minimization objectives;
- one new point per optimization iteration;
- bounded continuous design variables;
- one deterministic aggregate label, feasible or infeasible;
- a mean-only clipped Gaussian-process feasibility field;
- objective Thompson draws followed by sampled hypervolume improvement (HVI);
- explicit search safeguards and selection-source logging.

The field denoted by \(p_i\) is an operational feasibility score. It is not a
Bernoulli posterior and must not be described as a calibrated probability
unless calibration is established separately.

## Relationship to Bradford TSEMO

The release starts from the algorithmic sequence in Bradford et al.:

1. fit one Gaussian-process surrogate to each objective;
2. draw one posterior objective function per objective;
3. approximate the Pareto set of the sampled functions;
4. compute the HVI of candidates against the current feasible front; and
5. evaluate the selected candidate.

cTSEMO adds only the components needed to operate with an aggregate binary
feasibility response:

- an exact clipped Gaussian-process feasibility field;
- a locally variable length-scale option with a stationary fallback;
- design-space and objective-space anti-clustering masks;
- a separately seeded finite challenger pool evaluated with the same
  acquisition;
- a feasibility-discovery state for an initial design containing no feasible
  observations;
- explicit low-acquisition and duplicate-avoidance fallbacks; and
- immutable per-iteration diagnostics for the acquisition decomposition and
  final point-selection source.

The unmodified Bradford MATLAB files retained for provenance are under
`vendor/bradford-tsemo/`. They are pinned to upstream commit
`9ec2aa2f54d1232f80d37494ac067f2ebc112688`. They are not the cTSEMO public
entry point.

## Binary feasibility field

For each evaluated design \(\mathbf{x}_j\), cTSEMO records

\[
y_j =
\begin{cases}
1, & \mathbf{x}_j\ \text{is feasible},\\
0, & \mathbf{x}_j\ \text{is infeasible}.
\end{cases}
\]

The artificial regression target is

\[
z_j =
\begin{cases}
z_+, & y_j=1,\\
z_-, & y_j=0,
\end{cases}
\qquad z_+=1.25,\quad z_-=-0.25
\]

by default. Both margins are adjustable. A zero-noise Gaussian-process
interpolant produces a raw mean \(m_{\mathrm{raw}}(\mathbf{x})\), after which

\[
p_i(\mathbf{x}) =
\min\!\left(1,\max\!\left(0,m_{\mathrm{raw}}(\mathbf{x})\right)\right).
\]

Consequently, under consistent labels and adequate numerical conditioning,
the clipped field is 1 at known feasible sites and 0 at known infeasible
sites. Values can exceed \([0,1]\) before clipping. The release uses the mean
field only; it does not add a Thompson-sampled feasibility residual.

The locally variable length scale enlarges correlation length in regions
supported by dense, locally consistent infeasible observations. Its strength
is bounded and can revert to the stationary model. This is a geometric
regularization of the interpolation field, not evidence that unexplored
regions are infeasible.

## Acquisition and candidate selection

For iteration \(k\), let \(H_k^{\mathrm{TS}}(\mathbf{x})\) be the
nonnegative HVI produced by one pair of Thompson-sampled objective functions.
The main acquisition has the transparent factorization

\[
A_k(\mathbf{x}) =
\left[H_k^{\mathrm{TS}}(\mathbf{x})+\epsilon_k\right]
p_{i,k}(\mathbf{x})^{\alpha}
M_{X,k}(\mathbf{x})M_{Y,k}(\mathbf{x}),
\]

where \(M_X\) and \(M_Y\) are bounded anti-clustering masks. The quantity is
sampled HVI, not expected HVI. The exponent is configured by
`options.acquisition.pofPower`; its release default is \(\alpha=1\).

The release evaluates this acquisition on two deterministic finite candidate
pools:

- a primary Latin-hypercube pool, augmented with hyperrectangle corners when
  enabled and dimensionally permitted; and
- a separately seeded Latin-hypercube challenger pool.

Every candidate in both pools is scored before the primary and challenger
maxima are compared. This complete-pool policy avoids a multiple-comparisons
imbalance caused by Pareto-filtering only the primary pool. The challenger is
therefore a finite-search safeguard, not a different scientific acquisition.
Set `options.challengers.scoreCompletePools=false` only to reproduce the
legacy primary-only Pareto-filtering policy for an ablation. The release does
not continuously optimize or locally refine the acquisition.

### No feasible point in the initial design

An all-infeasible initial design makes the clipped interpolant zero at every
known site and leaves no feasible Pareto front. cTSEMO therefore enters an
objective-independent Phase-I feasibility-discovery state. On the finite
candidate pools it maximizes

\[
S_{\mathrm{I}}(\mathbf{x}) =
\max\!\left(p_i(\mathbf{x}),p_{\mathrm{floor}}\right)
\left[1-\exp\!\left(-d_{\min}(\mathbf{x})/s_d\right)\right],
\]

where the release defaults are \(p_{\mathrm{floor}}=0.60\) and \(s_d=0.10\)
in normalized design coordinates. When \(p_i\) is zero throughout the pool,
this is monotone in distance to the nearest evaluated point and therefore
reduces to finite-pool maximin exploration. It does not fabricate a Pareto
front from infeasible observations. The transition to ordinary sampled-HVI
selection occurs after the first feasible evaluation.

### Other fallbacks

If sampled HVI is zero throughout the finite pools, the acquisition is
nonfinite, or no valid candidate remains after duplicate exclusion, cTSEMO
uses an explicitly logged recovery path. Recovery prioritizes design-space
coverage and the available clipped feasibility field without being reported
as HVI. An absent or invalid pool requests candidate regeneration. A zero
sampled-HVI iteration is not an optimization stopping rule.

`options.fallback.enabled` controls the optional transition from an
acquisition-status or low-acquisition condition to the feasibility-novelty
fallback. It does not disable liveness-critical safeguards. Phase-I selection
before the first feasible observation, recovery from candidate-generation or
nonfinite-search failures, hard duplicate exclusion, and pool regeneration
can still invoke recovery when `options.fallback.enabled=false`.

## Reproducibility and diagnostics

Every expensive evaluation should be counted, including failed or rejected
proposals. A run record should preserve:

- normalized and physical design variables;
- both objective values and the aggregate binary label;
- objective and feasibility-model settings;
- random seeds;
- sampled HVI, \(p_i\), masks, final acquisition, and fallback score;
- primary and challenger pool maxima and their acquisition values;
- the final selection source and fallback reason;
- feasible Pareto set and hypervolume history; and
- MATLAB release, toolbox versions, release version, vendored Bradford
  revision, and wall-clock timing.

Each newly sealed benchmark campaign carries campaign-local
`release_source_manifest.csv`, `release_source_manifest.sha256`,
`release_source_manifest.mat`, and `release_source_manifest.json` files. The
CSV lists SHA-256 hashes for the public API, core package, diagnostics,
examples, benchmark sources and documentation, tests and test evidence, root
documentation, and vendored Bradford provenance files. Generated benchmark,
diagnostic, and output directories are excluded to avoid a recursive
manifest. The digest in `release_source_manifest.sha256` is the campaign
authority for the CSV and its listed source state; it is not a claim of a Git
commit. Archive these manifest files with every campaign used as evidence.

Dense two-dimensional fields and four-dimensional rank-raster diagnostics
should be generated after optimization from immutable run records. The
four-dimensional sorted raster is a rank-layout diagnostic, not a continuous
geometric projection.

## Installation and use

Add the release root to the MATLAB path. The public interface is

```matlab
options = cTSEMOOptions();
result = cTSEMO(f, g, X0, Y0, C0, lb, ub, options);
```

The inputs are:

- `f`: expensive objective function returning exactly two minimization
  objectives for one design;
- `g`: expensive feasibility function; a logical aggregate label is the
  preferred transport, while a vector of continuous inequality values is
  accepted and reduced internally to one aggregate label;
- `X0`: initial physical design matrix, one design per row;
- `Y0`: corresponding two-column objective matrix;
- `C0`: initial logical labels or continuous inequality observations, one row
  per initial design;
- `lb`, `ub`: lower and upper design bounds; and
- `options`: a struct produced by `cTSEMOOptions`, optionally with validated
  overrides.

Logical values are interpreted directly, with `true` denoting feasibility;
for a logical row vector, all entries must be true. Continuous inequalities
are feasible only when every returned value is finite and no greater than
zero. The number of values returned by `g` at every sequential evaluation
must equal the number of columns in `C0`.

Numeric data containing only 0 and 1 are deliberately rejected under the
default `options.feasibility.inputEncoding="auto"` because their meaning is
ambiguous. Set the encoding explicitly to `"feasibleIsOne"`,
`"feasibleIsZero"`, or `"continuousInequality"` as appropriate. For an
unconstrained problem, use `g=[]` and `C0=[]`.

Regardless of transport, the feasibility model and acquisition consume only
the reduced logical aggregate label; continuous violation magnitudes are not
used by the PoF model. The returned canonical struct has `meta`, `problem`,
`options`, `data`, `iterations`, and `pareto` sections. Its stored histories
are the source of diagnostic and benchmark figures.

Executable examples are stored in `examples/`, benchmark definitions in
`benchmarks/`, diagnostic utilities in `diagnostics/`, and class-based tests
in `tests/`. Refer to the MATLAB help text for the exact option schema and
label-encoding contract.

The development and verification environment for this release is MATLAB
R2025b. The minimum compatible MATLAB release is not established in the
available evidence. Users should run the bundled tests in their own
environment before relying on a result.

The vendored Bradford provenance snapshot intentionally excludes the original
DIRECT, NGPM, and MEX directories. See `THIRD_PARTY_NOTICES.md`.

## Benchmark and claim boundaries

Only benchmark artifacts shipped with the release are evidence for this exact
version. Earlier vMF-Wendland, in-hull, or Thompson-sampled-PoF experiments do
not validate the present clipped-GP formulation.

Existing welded-beam competitor runs in the wider research workspace use
different initial designs, seeds, implementations, and constraint
information. They are suitable as provenance-labelled exploratory results,
not as evidence of solver superiority. In particular, most external solvers
modelled continuous per-constraint margins whereas the cTSEMO PoF and
acquisition used only the reduced aggregate binary label, even when continuous
values were transported for bookkeeping. Any comparative conclusion must
state this information mismatch and must be limited to the tested
implementation and experimental conditions.

## Citation

Use `CITATION.cff` for software metadata and cite the original TSEMO article:

> E. Bradford, A. M. Schweidtmann, and A. A. Lapkin, “Efficient
> multiobjective optimization employing Gaussian processes, spectral sampling
> and a genetic algorithm,” *Journal of Global Optimization*, 71(2), 407–438,
> 2018. https://doi.org/10.1007/s10898-018-0609-2

## License

New cTSEMO release files are distributed under the BSD 2-Clause License; see
`LICENSE`. The Bradford source snapshot retains its original copyright and
BSD 2-Clause license under `vendor/bradford-tsemo/LICENSE`.
