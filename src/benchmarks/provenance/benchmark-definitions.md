# BNH, SRN, and welded-beam definitions

The executable definitions are independently written in
`src/benchmarks/getBenchmarkProblem.m`. This note records the equations and
literature attribution without redistributing third-party implementation
files. Every constraint is stored as a margin that must satisfy `G <= 0`.

## BNH (Binh-Korn)

For `0 <= x1 <= 5` and `0 <= x2 <= 3`,

```text
f1 = 4 (x1^2 + x2^2)
f2 = (x1 - 5)^2 + (x2 - 5)^2
g1 = (x1 - 5)^2 + x2^2 - 25
g2 = 7.7 - (x1 - 8)^2 - (x2 + 3)^2
```

The formulation is the Binh-Korn constrained multiobjective benchmark.

## SRN (Srinivas-Deb)

For `-20 <= x1,x2 <= 20`,

```text
f1 = (x1 - 2)^2 + (x2 - 1)^2 + 2
f2 = 9 x1 - (x2 - 1)^2
g1 = x1^2 + x2^2 - 225
g2 = x1 - 3 x2 + 10
```

The implementation uses the standard quadratic circle and the
`(x2 - 1)^2` objective term.

## Welded-beam variant used in the manuscript

The four variables are `(h,l,t,b)` with bounds
`[0.125,0.1,0.1,0.125] <= x <= [5,10,10,5]`. The load is 6000 lb, beam length
is 14 in, and Young's modulus is 30 million psi. The two objectives are

```text
f1 = 1.10471 h^2 l + 0.04811 t b (14 + t)
f2 = 4 P L^3 / (E b t^3)
```

The four margins implement the 13,600 psi shear limit, 30,000 psi normal
stress limit, `h <= b`, and the critical-load expression
`64764.022 (1 - 0.0282346 t) t b^3 >= P`. The complete vectorized equations
are in `getBenchmarkProblem.m` and match the exact variant used by the retained
WB150 run records. The general welded-beam benchmark lineage is attributed to
Ray and Liew (2002); this repository does not claim that its cost and buckling
coefficients are universal across published variants.

## References

- T. T. Binh and U. Korn, “MOBES: A multiobjective evolution strategy for
  constrained optimization problems,” 1997.
- K. Deb, A. Pratap, S. Agarwal, and T. Meyarivan, “A fast and elitist
  multiobjective genetic algorithm: NSGA-II,” *IEEE Transactions on
  Evolutionary Computation*, 6(2), 182-197, 2002.
  <https://doi.org/10.1109/4235.996017>
- T. Ray and K. M. Liew, “A swarm metaphor for multiobjective design
  optimization,” *Engineering Optimization*, 34(2), 141-153, 2002.
