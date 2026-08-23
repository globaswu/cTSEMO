# Higher-dimensional benchmark provenance

The executable equations in `src/benchmarks/getBenchmarkProblem.m` follow the
sources identified below. cTSEMO uses the convention that every constraint
margin must satisfy `G <= 0`.

## C2-DTLZ2 and OSY

The C2-DTLZ2 and OSY implementations were checked against the BoTorch
definitions in `botorch/test_functions/multi_objective.py` at commit
`46cc96bc82fda27a35c680828c2e8e96068bf8d1`:

<https://github.com/pytorch/botorch/blob/46cc96bc82fda27a35c680828c2e8e96068bf8d1/botorch/test_functions/multi_objective.py>

BoTorch reports nonnegative feasibility slack for these problems. The MATLAB
registry negates that slack to implement its documented `G <= 0` convention.
The study uses two-objective C2-DTLZ2 instances with radius 0.2 in four and six
design variables, and the standard six-variable OSY instance.

## MW7

The MW7 implementation was checked against the same pinned BoTorch source.
The source supports arbitrary dimension greater than one; the manuscript
campaign uses four- and six-variable instances. The MATLAB expressions are
returned with the sign required by the `G <= 0` convention.

## CF1

CF1 is implemented directly from the equations in:

Q. Zhang, A. Zhou, S. Zhao, P. N. Suganthan, W. Liu, and S. Tiwari,
*Multiobjective Optimization Test Instances for the CEC 2009 Special Session
and Competition*, Technical Report CES-487, University of Essex, 2009.

The report defines feasibility using a nonnegative slack. The MATLAB registry
stores the negative of that slack, so feasible designs satisfy `G <= 0`. The
reported campaign uses the standard parameters `N = 10` and `a = 1` in four
and ten design variables.

## Scope

These are deterministic, dimensionless mathematical benchmarks. The source
references document formula provenance; they do not imply endorsement of
cTSEMO or establish comparative optimizer performance.
