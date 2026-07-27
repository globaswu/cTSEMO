function problem = getBenchmarkProblem(problemId)
%GETBENCHMARKPROBLEM Return a source-traced constrained benchmark definition.
%   PROBLEM = GETBENCHMARKPROBLEM(PROBLEMID) returns a struct whose
%   objective is a vectorized two-objective minimization function and whose
%   constraintMargins function returns G(X), with a row feasible iff every
%   entry in that row satisfies G <= 0.
%
%   The label01 handle returns 1 for feasible points and 0 for violating
%   points. The binaryConstraint handle returns -1 for feasible points and
%   +1 for violating points, matching the legacy cTSEMO constraint sign.
%
%   Available identifiers (aliases in parentheses):
%     COSSIN1
%     COSSIN2
%     BNH (BK2, BINHKORN)
%     SRN (BK1, SRINIVASDEB)
%     WELDEDBEAM (WB)
%     C2DTLZ2
%     C2DTLZ2_D4_R02 (C2DTLZ2_D4)
%     C2DTLZ2_D6_R02 (C2DTLZ2_D6)
%     OSY
%     MW7_D4
%     MW7_D6 (MW7)
%     CF1_D4
%     CF1_D10 (CF1)
%
%   All equations and bounds below are transcribed from files already
%   present in this workspace. No fixed hypervolume reference was found in
%   those definitions, so hypervolumeReference is explicitly empty.

narginchk(1, 1);
validateattributes(problemId, {'char', 'string'}, {'scalartext'}, ...
    mfilename, 'problemId');

key = lower(regexprep(char(problemId), '[^a-zA-Z0-9]', ''));

switch key
    case 'cossin1'
        problem = cossinProblem(1);
    case 'cossin2'
        problem = cossinProblem(2);
    case {'bnh', 'bk2', 'binhkorn'}
        problem = bnhProblem();
    case {'srn', 'bk1', 'srinivasdeb'}
        problem = srnProblem();
    case {'weldedbeam', 'weldbeam', 'wb'}
        problem = weldedBeamProblem();
    case {'c2dtlz2', 'c2dtlz2d3'}
        problem = c2dtlz2Problem(3, 0.5, ...
            'C2DTLZ2', 'C2-DTLZ2 (M=2, D=3, r=0.5)');
    case {'c2dtlz2d4r02', 'c2dtlz2d4'}
        problem = c2dtlz2Problem(4, 0.2, ...
            'C2DTLZ2_D4_R02', 'C2-DTLZ2 (M=2, D=4, r=0.2)');
    case {'c2dtlz2d6r02', 'c2dtlz2d6'}
        problem = c2dtlz2Problem(6, 0.2, ...
            'C2DTLZ2_D6_R02', 'C2-DTLZ2 (M=2, D=6, r=0.2)');
    case {'osy', 'osyd6'}
        problem = osyProblem();
    case 'mw7d4'
        problem = mw7Problem(4);
    case {'mw7', 'mw7d6'}
        problem = mw7Problem(6);
    case 'cf1d4'
        problem = cf1Problem(4);
    case {'cf1', 'cf1d10'}
        problem = cf1Problem(10);
    otherwise
        error('cTSEMO:UnknownBenchmark', ...
            'Unknown benchmark "%s". See help getBenchmarkProblem.', ...
            char(problemId));
end

problem.constraint = problem.constraintMargins;
problem.feasible = @(X) feasibilityFromMargins( ...
    problem.constraintMargins(X));
problem.label01 = @(X) double(problem.feasible(X));
problem.binaryConstraint = @(X) 2 .* double(~problem.feasible(X)) - 1;
problem.f = problem.objective;
problem.g = problem.constraintMargins;
problem.lb = problem.lowerBound;
problem.ub = problem.upperBound;
problem.hypervolumeReference = [];
problem.hypervolumeReferenceNote = 'Not found in available files.';
end

function problem = cossinProblem(problemNumber)
% Source: this shipped registry, transcribed from the July 2026 workspace
% cossinObjective and cossinConstraint local functions.
problem = baseProblem();
problem.id = sprintf('COSSIN%d', problemNumber);
problem.name = sprintf('COSSIN problem %d', problemNumber);
problem.dimension = 2;
problem.lowerBound = [0, 0];
problem.upperBound = [1, 1];
problem.objective = @cossinObjective;
problem.constraintMargins = @(X) cossinConstraint(X, problemNumber);
problem.variableNames = {'x_1', 'x_2'};
problem.variableUnits = {'dimensionless', 'dimensionless'};
problem.objectiveNames = {'f_1', 'f_2'};
problem.objectiveUnits = {'dimensionless', 'dimensionless'};
problem.constraintNames = {'outside disk 1', 'outside disk 2', ...
    'outside disk 3', 'x_1 + x_2 <= 1'};
problem.constraintUnits = repmat({'dimensionless'}, 1, 4);
problem.sourceFiles = {'benchmarks/getBenchmarkProblem.m'};
problem.notes = ['Synthetic two-variable problem used in the existing ' ...
    'COSSIN studies. Positive margins violate feasibility.'];
end

function problem = bnhProblem()
% Sources:
%   benchmarks/provenance/bradford-test-functions/ttbuk2.m
%   benchmarks/provenance/bradford-test-functions/ttbukg2.m
% The canonical BNH domain [0,5] x [0,3] is retained here rather than the
% wider matched-domain stress interval used by some earlier scripts.
problem = baseProblem();
problem.id = 'BNH';
problem.name = 'Binh-Korn BNH';
problem.dimension = 2;
problem.lowerBound = [0, 0];
problem.upperBound = [5, 3];
problem.objective = @bnhObjective;
problem.constraintMargins = @bnhConstraint;
problem.variableNames = {'x_1', 'x_2'};
problem.variableUnits = {'dimensionless', 'dimensionless'};
problem.objectiveNames = {'f_1', 'f_2'};
problem.objectiveUnits = {'dimensionless', 'dimensionless'};
problem.constraintNames = {'inside radius-5 disk', ...
    'outside excluded disk'};
problem.constraintUnits = {'dimensionless', 'dimensionless'};
problem.sourceFiles = { ...
    'benchmarks/provenance/bradford-test-functions/ttbuk2.m', ...
    'benchmarks/provenance/bradford-test-functions/ttbukg2.m'};
problem.notes = ['Canonical bounded BNH definition. This benchmark can ' ...
    'also be requested using the historical alias BK2.'];
end

function problem = srnProblem()
% Sources:
%   benchmarks/provenance/bradford-test-functions/ttbuk1.m
%   benchmarks/provenance/bradford-test-functions/ttbukg1.m
% These files contain the standard quadratic circle x1^2+x2^2 <= 225 and
% the (x2-1)^2 objective term. Do not copy the older generated audit
% variant that used fourth powers and shifted the first objective.
problem = baseProblem();
problem.id = 'SRN';
problem.name = 'Srinivas-Deb SRN';
problem.dimension = 2;
problem.lowerBound = [-20, -20];
problem.upperBound = [20, 20];
problem.objective = @srnObjective;
problem.constraintMargins = @srnConstraint;
problem.variableNames = {'x_1', 'x_2'};
problem.variableUnits = {'dimensionless', 'dimensionless'};
problem.objectiveNames = {'f_1', 'f_2'};
problem.objectiveUnits = {'dimensionless', 'dimensionless'};
problem.constraintNames = {'x_1^2 + x_2^2 <= 225', ...
    'x_1 - 3 x_2 + 10 <= 0'};
problem.constraintUnits = {'dimensionless', 'dimensionless'};
problem.sourceFiles = { ...
    'benchmarks/provenance/bradford-test-functions/ttbuk1.m', ...
    'benchmarks/provenance/bradford-test-functions/ttbukg1.m'};
problem.notes = ['Corrected standard SRN definition. This benchmark can ' ...
    'also be requested using the historical alias BK1.'];
end

function problem = weldedBeamProblem()
% Sources:
%   benchmarks/provenance/bradford-test-functions/weldbeam.m
%   benchmarks/provenance/bradford-test-functions/weldbeamconstr.m
%   cTSEMOp/run_weldbeam_variant_150.m (vectorized transcription and bounds)
% The implementation uses the existing imperial-unit formulation: force in
% lb, lengths in in, and stress/modulus in psi.
problem = baseProblem();
problem.id = 'WELDEDBEAM';
problem.name = 'Welded-beam design';
problem.dimension = 4;
problem.lowerBound = [0.125, 0.1, 0.1, 0.125];
problem.upperBound = [5, 10, 10, 5];
problem.objective = @weldedBeamObjective;
problem.constraintMargins = @weldedBeamConstraint;
problem.variableNames = {'h', 'l', 't', 'b'};
problem.variableUnits = {'in', 'in', 'in', 'in'};
problem.objectiveNames = {'fabrication cost', 'end deflection'};
problem.objectiveUnits = {'cost units', 'in'};
problem.constraintNames = {'shear stress', 'normal stress', ...
    'weld/beam thickness ordering', 'buckling load'};
problem.constraintUnits = {'psi', 'psi', 'in', 'lb'};
problem.sourceFiles = { ...
    'benchmarks/provenance/bradford-test-functions/weldbeam.m', ...
    'benchmarks/provenance/bradford-test-functions/weldbeamconstr.m', ...
    'benchmarks/getBenchmarkProblem.m'};
problem.notes = ['Exact four-constraint formulation and bounds used by ' ...
    'the existing WB150 scripts. Objective 1 has empirical cost units.'];
end

function problem = c2dtlz2Problem(dimension, radius, identifier, name)
% Sources: benchmarks/provenance/c2dtlz2_reference.m and
% benchmarks/provenance/high-dimensional-benchmarks.md.
problem = baseProblem();
problem.id = identifier;
problem.name = name;
problem.dimension = dimension;
problem.lowerBound = zeros(1, dimension);
problem.upperBound = ones(1, dimension);
problem.objective = @(X) c2dtlz2Objective(X, dimension);
problem.constraintMargins = ...
    @(X) c2dtlz2Constraint(X, dimension, radius);
problem.variableNames = indexedNames('x', dimension);
problem.variableUnits = repmat({'dimensionless'}, 1, dimension);
problem.objectiveNames = {'f_1', 'f_2'};
problem.objectiveUnits = {'dimensionless', 'dimensionless'};
problem.constraintNames = {'C2-DTLZ2 disconnected-feasibility margin'};
problem.constraintUnits = {'dimensionless'};
problem.sourceFiles = { ...
    'benchmarks/provenance/c2dtlz2_reference.m', ...
    'benchmarks/provenance/high-dimensional-benchmarks.md'};
problem.notes = sprintf([ ...
    'Two-objective, %d-variable form with constraint radius r = %.3g. ' ...
    'The dimension and radius are explicit in the problem identifier.'], ...
    dimension, radius);
end

function problem = osyProblem()
% Source: benchmarks/provenance/high-dimensional-benchmarks.md.
problem = baseProblem();
problem.id = 'OSY';
problem.name = 'Osyczka-Kundu OSY';
problem.dimension = 6;
problem.lowerBound = [0, 0, 1, 0, 1, 0];
problem.upperBound = [10, 10, 5, 6, 5, 10];
problem.objective = @osyObjective;
problem.constraintMargins = @osyConstraint;
problem.variableNames = indexedNames('x', 6);
problem.variableUnits = repmat({'dimensionless'}, 1, 6);
problem.objectiveNames = {'f_1', 'f_2'};
problem.objectiveUnits = {'dimensionless', 'dimensionless'};
problem.constraintNames = { ...
    'x_1 + x_2 >= 2', ...
    'x_1 + x_2 <= 6', ...
    'x_2 - x_1 <= 2', ...
    'x_1 - 3 x_2 <= 2', ...
    '(x_3 - 3)^2 + x_4 <= 4', ...
    '(x_5 - 3)^2 + x_6 >= 4'};
problem.constraintUnits = repmat({'dimensionless'}, 1, 6);
problem.sourceFiles = { ...
    'benchmarks/provenance/high-dimensional-benchmarks.md'};
problem.notes = ['Canonical six-variable, two-objective OSY problem. ' ...
    'Margins are sign-converted so that G <= 0 denotes feasibility.'];
end

function problem = mw7Problem(dimension)
% Source: benchmarks/provenance/high-dimensional-benchmarks.md.
problem = baseProblem();
problem.id = sprintf('MW7_D%d', dimension);
problem.name = sprintf('MW7 (M=2, D=%d)', dimension);
problem.dimension = dimension;
problem.lowerBound = zeros(1, dimension);
problem.upperBound = ones(1, dimension);
problem.objective = @(X) mw7Objective(X, dimension);
problem.constraintMargins = @(X) mw7Constraint(X, dimension);
problem.variableNames = indexedNames('x', dimension);
problem.variableUnits = repmat({'dimensionless'}, 1, dimension);
problem.objectiveNames = {'f_1', 'f_2'};
problem.objectiveUnits = {'dimensionless', 'dimensionless'};
problem.constraintNames = { ...
    'outside MW7 outer radius', ...
    'inside MW7 inner radius'};
problem.constraintUnits = {'dimensionless', 'dimensionless'};
problem.sourceFiles = { ...
    'benchmarks/provenance/high-dimensional-benchmarks.md'};
problem.notes = sprintf([ ...
    '%d-variable instance of the arbitrary-dimensional MW7 problem ' ...
    'with a disconnected feasible Pareto front.'], dimension);
end

function problem = cf1Problem(dimension)
% Source: benchmarks/provenance/high-dimensional-benchmarks.md.
problem = baseProblem();
problem.id = sprintf('CF1_D%d', dimension);
problem.name = sprintf('CEC 2009 CF1 (M=2, D=%d)', dimension);
problem.dimension = dimension;
problem.lowerBound = zeros(1, dimension);
problem.upperBound = ones(1, dimension);
problem.objective = @(X) cf1Objective(X, dimension);
problem.constraintMargins = @(X) cf1Constraint(X, dimension);
problem.variableNames = indexedNames('x', dimension);
problem.variableUnits = repmat({'dimensionless'}, 1, dimension);
problem.objectiveNames = {'f_1', 'f_2'};
problem.objectiveUnits = {'dimensionless', 'dimensionless'};
problem.constraintNames = {'CEC 2009 CF1 oscillatory margin'};
problem.constraintUnits = {'dimensionless'};
problem.sourceFiles = { ...
    'benchmarks/provenance/high-dimensional-benchmarks.md'};
problem.notes = sprintf([ ...
    '%d-variable CEC 2009 CF1 transcription from the ' ...
    'repository-contained PlatEMO implementation.'], dimension);
end

function problem = baseProblem()
problem = struct( ...
    'id', '', ...
    'name', '', ...
    'dimension', [], ...
    'lowerBound', [], ...
    'upperBound', [], ...
    'objective', [], ...
    'constraintMargins', [], ...
    'variableNames', {{}}, ...
    'variableUnits', {{}}, ...
    'objectiveNames', {{}}, ...
    'objectiveUnits', {{}}, ...
    'constraintNames', {{}}, ...
    'constraintUnits', {{}}, ...
    'sourceFiles', {{}}, ...
    'notes', '');
end

function F = cossinObjective(X)
X = asRows(X, 2);
x1 = X(:, 1);
x2 = X(:, 2);
F = [sin(pi .* x1) + cos(pi .* x2), ...
    cos(pi .* x1) - sin(pi .* x2)];
end

function G = cossinConstraint(X, problemNumber)
X = asRows(X, 2);
x1 = X(:, 1);
x2 = X(:, 2);
if problemNumber == 1
    radius = 0.20;
    centers = [0.30, 0.70; 0.50, 0.50; 0.70, 0.30];
else
    radius = 0.15;
    centers = [0.10, 0.70; 0.40, 0.40; 0.70, 0.10];
end
G = zeros(size(X, 1), 4);
G(:, 1) = radius - hypot(x1 - centers(1, 1), ...
    x2 - centers(1, 2));
G(:, 2) = radius - hypot(x1 - centers(2, 1), ...
    x2 - centers(2, 2));
G(:, 3) = radius - hypot(x1 - centers(3, 1), ...
    x2 - centers(3, 2));
G(:, 4) = x1 + x2 - 1;
end

function F = bnhObjective(X)
X = asRows(X, 2);
x1 = X(:, 1);
x2 = X(:, 2);
F = [4 .* (x1 .^ 2 + x2 .^ 2), ...
    (x1 - 5) .^ 2 + (x2 - 5) .^ 2];
end

function G = bnhConstraint(X)
X = asRows(X, 2);
x1 = X(:, 1);
x2 = X(:, 2);
G = [(x1 - 5) .^ 2 + x2 .^ 2 - 25, ...
    7.7 - (x1 - 8) .^ 2 - (x2 + 3) .^ 2];
end

function F = srnObjective(X)
X = asRows(X, 2);
x1 = X(:, 1);
x2 = X(:, 2);
F = [(x1 - 2) .^ 2 + (x2 - 1) .^ 2 + 2, ...
    9 .* x1 - (x2 - 1) .^ 2];
end

function G = srnConstraint(X)
X = asRows(X, 2);
x1 = X(:, 1);
x2 = X(:, 2);
G = [x1 .^ 2 + x2 .^ 2 - 225, ...
    x1 - 3 .* x2 + 10];
end

function F = weldedBeamObjective(X)
X = asRows(X, 4);
loadPounds = 6000;
beamLengthInches = 14;
youngsModulusPsi = 30e6;
h = X(:, 1);
l = X(:, 2);
t = X(:, 3);
b = X(:, 4);
F = [1.10471 .* h .^ 2 .* l + ...
    0.04811 .* t .* b .* (14 + t), ...
    4 .* loadPounds .* beamLengthInches .^ 3 ./ ...
    (youngsModulusPsi .* b .* t .^ 3)];
end

function G = weldedBeamConstraint(X)
X = asRows(X, 4);
loadPounds = 6000;
beamLengthInches = 14;
maximumShearPsi = 13600;
maximumNormalPsi = 30000;
h = X(:, 1);
l = X(:, 2);
t = X(:, 3);
b = X(:, 4);

bendingMoment = loadPounds .* (beamLengthInches + 0.5 .* l);
radius = sqrt(l .^ 2 ./ 4 + 0.25 .* (h + t) .^ 2);
polarMoment = sqrt(2) .* h .* l .* ...
    (l .^ 2 ./ 12 + 0.25 .* (l .^ 2 + (h + t) .^ 2));
primaryShear = loadPounds ./ (sqrt(2) .* h .* l);
secondaryShear = bendingMoment .* radius ./ polarMoment;
shearStress = sqrt(primaryShear .^ 2 + ...
    primaryShear .* secondaryShear .* l ./ radius + ...
    secondaryShear .^ 2);
normalStress = 6 .* loadPounds .* beamLengthInches ./ (b .* t .^ 2);
criticalLoad = 64764.022 .* (1 - 0.0282346 .* t) .* t .* b .^ 3;

G = [shearStress - maximumShearPsi, ...
    normalStress - maximumNormalPsi, ...
    h - b, ...
    loadPounds - criticalLoad];
end

function F = c2dtlz2Objective(X, dimension)
X = asRows(X, dimension);
g = sum((X(:, 2:end) - 0.5) .^ 2, 2);
F = [(1 + g) .* cos(X(:, 1) .* pi ./ 2), ...
    (1 + g) .* sin(X(:, 1) .* pi ./ 2)];
end

function G = c2dtlz2Constraint(X, dimension, radius)
numberOfObjectives = 2;
F = c2dtlz2Objective(X, dimension);
sumOfSquares = sum(F .^ 2, 2);
axisCentered = (F - 1) .^ 2 + sumOfSquares - F .^ 2 - radius .^ 2;
diagonalCentered = sum((F - 1 ./ sqrt(numberOfObjectives)) .^ 2, 2) ...
    - radius .^ 2;
G = min(min(axisCentered, [], 2), diagonalCentered);
end

function F = osyObjective(X)
X = asRows(X, 6);
x1 = X(:, 1);
x2 = X(:, 2);
x3 = X(:, 3);
x4 = X(:, 4);
x5 = X(:, 5);
f1 = -(25 .* (x1 - 2) .^ 2 + (x2 - 2) .^ 2 + ...
    (x3 - 1) .^ 2 + (x4 - 4) .^ 2 + (x5 - 1) .^ 2);
f2 = sum(X .^ 2, 2);
F = [f1, f2];
end

function G = osyConstraint(X)
X = asRows(X, 6);
x1 = X(:, 1);
x2 = X(:, 2);
x3 = X(:, 3);
x4 = X(:, 4);
x5 = X(:, 5);
x6 = X(:, 6);
feasibilitySlack = [ ...
    x1 + x2 - 2, ...
    6 - x1 - x2, ...
    2 - x2 + x1, ...
    2 - x1 + 3 .* x2, ...
    4 - (x3 - 3) .^ 2 - x4, ...
    (x5 - 3) .^ 2 + x6 - 4];
G = -feasibilitySlack;
end

function F = mw7Objective(X, dimension)
X = asRows(X, dimension);
a = X(:, 1:end-1) - 0.5;
contribution = 2 .* (X(:, 2:end) + a .^ 2 - 1) .^ 2;
g = 1 + sum(contribution, 2);
f1 = g .* X(:, 1);
f2 = g .* sqrt(max(0, 1 - X(:, 1) .^ 2));
F = [f1, f2];
end

function G = mw7Constraint(X, dimension)
F = mw7Objective(X, dimension);
f1 = F(:, 1);
f2 = F(:, 2);
theta = atan2(f2, f1);
outerWave = 0.4 .* sin(4 .* theta) .^ 16;
innerWave = 0.2 .* sin(4 .* theta) .^ 8;
radiusSquared = f1 .^ 2 + f2 .^ 2;
G = [ ...
    radiusSquared - (1.2 + abs(outerWave)) .^ 2, ...
    (1.15 - innerWave) .^ 2 - radiusSquared];
end

function F = cf1Objective(X, dimension)
X = asRows(X, dimension);
oddIndices = 3:2:dimension;
evenIndices = 2:2:dimension;
x1 = X(:, 1);
oddPowers = 0.5 .* (1 + ...
    3 .* (oddIndices - 2) ./ (dimension - 2));
evenPowers = 0.5 .* (1 + ...
    3 .* (evenIndices - 2) ./ (dimension - 2));
oddTarget = x1 .^ oddPowers;
evenTarget = x1 .^ evenPowers;
f1 = x1 + 2 .* mean((X(:, oddIndices) - oddTarget) .^ 2, 2);
f2 = 1 - x1 + ...
    2 .* mean((X(:, evenIndices) - evenTarget) .^ 2, 2);
F = [f1, f2];
end

function G = cf1Constraint(X, dimension)
F = cf1Objective(X, dimension);
G = 1 - F(:, 1) - F(:, 2) + ...
    abs(sin(10 .* pi .* (F(:, 1) - F(:, 2) + 1)));
end

function names = indexedNames(prefix, count)
names = arrayfun(@(index) sprintf('%s_%d', prefix, index), ...
    1:count, 'UniformOutput', false);
end

function X = asRows(X, dimension)
validateattributes(X, {'numeric'}, {'2d', 'real'}, mfilename, 'X');
if isempty(X)
    X = zeros(0, dimension);
    return
end
if isvector(X) && numel(X) == dimension
    X = reshape(double(X), 1, dimension);
elseif size(X, 2) == dimension
    X = double(X);
else
    error('cTSEMO:BenchmarkDimensionMismatch', ...
        'Expected points with %d columns; received a %d-by-%d array.', ...
        dimension, size(X, 1), size(X, 2));
end
end

function feasible = feasibilityFromMargins(G)
feasible = all(isfinite(G) & G <= 0, 2);
end
