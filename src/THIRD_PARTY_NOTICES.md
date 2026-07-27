# Third-party notices

## Bradford TSEMO MATLAB source

Files:

- `vendor/bradford-tsemo/TSEMO_V4.m`
- `vendor/bradford-tsemo/TSEMO_options.m`
- `vendor/bradford-tsemo/README.md`
- `vendor/bradford-tsemo/LICENSE`

Source:

- Eric Bradford, Artur M. Schweidtmann, and Alexei A. Lapkin
- <https://github.com/Eric-Bradford/TS-EMO>
- pinned commit `9ec2aa2f54d1232f80d37494ac067f2ebc112688`

License: BSD 2-Clause. The complete upstream notice and license are retained in
`vendor/bradford-tsemo/LICENSE`.

The redistributed `TSEMO_V4.m` also contains third-party routines with their
own attribution and license notices embedded verbatim in the source:

- Yi Cao: `vendor/bradford-tsemo/TSEMO_V4.m`, lines 575--611;
- Carl Edward Rasmussen and Hannes Nickisch:
  `vendor/bradford-tsemo/TSEMO_V4.m`, lines 658--681 and 755--778; and
- Mo Chen: `vendor/bradford-tsemo/TSEMO_V4.m`, lines 718--748.

Those embedded notices are part of the redistributed file and remain
unaltered. Their exact terms are the text at the cited source locations; this
file does not replace or paraphrase those terms.

## Bradford-licensed benchmark reference files

Files:

- `benchmarks/provenance/bradford-test-functions/ttbuk1.m`
- `benchmarks/provenance/bradford-test-functions/ttbukg1.m`
- `benchmarks/provenance/bradford-test-functions/ttbuk2.m`
- `benchmarks/provenance/bradford-test-functions/ttbukg2.m`
- `benchmarks/provenance/bradford-test-functions/weldbeam.m`
- `benchmarks/provenance/bradford-test-functions/weldbeamconstr.m`
- `benchmarks/provenance/bradford-test-functions/LICENSE`

These files are content-preserving copies from the Bradford-licensed
`TSEMO-Constrain/Test_functions` research workspace as the formula evidence
for the shipped vectorized SRN, BNH, and welded-beam definitions. They are
covered by the BSD 2-Clause notice copied alongside them. The benchmark
registry does not execute these reference copies.

Related article:

E. Bradford, A. M. Schweidtmann, and A. A. Lapkin, “Efficient multiobjective
optimization employing Gaussian processes, spectral sampling and a genetic
algorithm,” *Journal of Global Optimization*, 71(2), 407–438, 2018.
<https://doi.org/10.1007/s10898-018-0609-2>

## Components intentionally not redistributed

The upstream Bradford repository contains or refers to additional dependency
trees, including DIRECT optimization code, NGPM code, and compiled or
compilable MEX sources/binaries. Those trees are not included in this cTSEMO
release. No license or compatibility conclusion is asserted for omitted
components.

The Bradford material redistributed inside this release is limited to the
four pinned TSEMO snapshot files and the seven benchmark-reference/license
files listed above. MATLAB itself is external commercial software and is not
redistributed.

## Higher-dimensional benchmark transcriptions

The executable C2-DTLZ2, OSY, and MW7 equations in
`benchmarks/getBenchmarkProblem.m` were transcribed from the
repository-contained BoTorch source at commit
`46cc96bc82fda27a35c680828c2e8e96068bf8d1`:

- `botorch/test_functions/multi_objective.py`, classes `C2DTLZ2`, `OSY`,
  and `MW7`.

BoTorch is distributed under the MIT License. The applicable license text is
retained at `benchmarks/provenance/botorch-LICENSE`. The upstream Python
source itself is not redistributed inside this release.

The CF1 equations were transcribed from the repository-contained PlatEMO
class `Problems/Multi-objective optimization/CF/CF1.m`. Its source header
identifies the CEC 2009 working report and requests acknowledgement of
PlatEMO in publications using the platform. The PlatEMO implementation is
not redistributed inside this release. Exact local source paths and
constraint-sign conversions for all four study problems are recorded in
`benchmarks/provenance/high-dimensional-benchmarks.md`.
