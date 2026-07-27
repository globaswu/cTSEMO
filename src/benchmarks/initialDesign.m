function [X, info] = initialDesign(problem, pointCount, seed, options)
%INITIALDESIGN Construct a deterministic LHS-plus-corners initial design.
%   X = INITIALDESIGN(PROBLEM, POINTCOUNT, SEED) includes every corner of
%   the problem hyperrectangle and fills the remaining rows by a local
%   randomized Latin-hypercube construction. For each dimension, the local
%   generator draws one RANDPERM of the strata followed by one independent
%   within-stratum RAND jitter per row. POINTCOUNT must therefore be at
%   least 2^D when corners are enabled.
%
%   X = INITIALDESIGN(..., OPTIONS) accepts:
%     IncludeCorners   logical scalar, default true
%     AllInfeasible    logical scalar, default false
%     OversampleFactor positive scalar, default 20
%     MaxBatches       positive integer, default 100
%
%   AllInfeasible is a deliberate fallback stress mode. It filters
%   deterministic Latin-hypercube candidate batches until every returned
%   point is violating. It overrides IncludeCorners because corners cannot
%   generally be guaranteed infeasible. This stress design is diagnostic;
%   it should not be presented as an ordinary random initial design.

narginchk(3, 4);
if nargin < 4 || isempty(options)
    options = struct();
end
if ischar(problem) || (isstring(problem) && isscalar(problem))
    problem = getBenchmarkProblem(problem);
end
validateProblem(problem);
validateattributes(pointCount, {'numeric'}, ...
    {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'pointCount');
validateattributes(seed, {'numeric'}, ...
    {'scalar', 'integer', 'nonnegative', 'finite'}, mfilename, 'seed');
validateattributes(options, {'struct'}, {'scalar'}, mfilename, 'options');

includeCorners = optionValue(options, 'IncludeCorners', true);
allInfeasible = optionValue(options, 'AllInfeasible', false);
oversampleFactor = optionValue(options, 'OversampleFactor', 20);
maxBatches = optionValue(options, 'MaxBatches', 100);
validateattributes(includeCorners, {'logical', 'numeric'}, ...
    {'scalar', 'binary'}, mfilename, 'options.IncludeCorners');
validateattributes(allInfeasible, {'logical', 'numeric'}, ...
    {'scalar', 'binary'}, mfilename, 'options.AllInfeasible');
validateattributes(oversampleFactor, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>=', 1}, ...
    mfilename, 'options.OversampleFactor');
validateattributes(maxBatches, {'numeric'}, ...
    {'scalar', 'integer', 'positive', 'finite'}, ...
    mfilename, 'options.MaxBatches');

includeCorners = logical(includeCorners);
allInfeasible = logical(allInfeasible);
previousRandomState = rng;
restoreRandomState = onCleanup(@() rng(previousRandomState));
rng(double(seed), 'twister');

if allInfeasible
    [X, batchCount] = infeasibleLhs(problem, pointCount, ...
        oversampleFactor, maxBatches);
    includedCornerCount = 0;
else
    dimension = problem.dimension;
    unitCorners = zeros(0, dimension);
    if includeCorners
        unitCorners = allCorners(dimension);
        if pointCount < size(unitCorners, 1)
            error('cTSEMO:TooFewInitialPointsForCorners', ...
                ['%d points cannot include all %d corners of a %d-D ' ...
                'hyperrectangle. Increase pointCount or set ' ...
                'IncludeCorners=false.'], ...
                pointCount, size(unitCorners, 1), dimension);
        end
    end
    lhsCount = pointCount - size(unitCorners, 1);
    unitLhs = zeros(0, dimension);
    if lhsCount > 0
        unitLhs = randomizedLhs(lhsCount, dimension);
    end
    X = scaleFromUnit([unitCorners; unitLhs], ...
        problem.lowerBound, problem.upperBound);
    batchCount = double(lhsCount > 0);
    includedCornerCount = size(unitCorners, 1);
end

feasible = problem.feasible(X);
if allInfeasible && any(feasible)
    error('cTSEMO:InvalidAllInfeasibleDesign', ...
        'Internal error: the stress design contains a feasible point.');
end

info = struct();
info.Seed = double(seed);
info.RequestedPointCount = double(pointCount);
info.ReturnedPointCount = size(X, 1);
info.IncludeCornersRequested = includeCorners;
info.IncludedCornerCount = includedCornerCount;
info.AllInfeasible = allInfeasible;
info.LhsBatchCount = batchCount;
info.FeasibleCount = nnz(feasible);
info.ViolatingCount = nnz(~feasible);

clear restoreRandomState
end

function [X, batchCount] = infeasibleLhs(problem, pointCount, ...
    oversampleFactor, maxBatches)
dimension = problem.dimension;
batchSize = max(pointCount, ceil(oversampleFactor .* pointCount));
X = zeros(0, dimension);
batchCount = 0;

while size(X, 1) < pointCount && batchCount < maxBatches
    batchCount = batchCount + 1;
    unitCandidates = randomizedLhs(batchSize, dimension);
    candidates = scaleFromUnit(unitCandidates, ...
        problem.lowerBound, problem.upperBound);
    candidates = candidates(~problem.feasible(candidates), :);
    X = unique([X; candidates], 'rows', 'stable');
end

if size(X, 1) < pointCount
    error('cTSEMO:InsufficientInfeasibleInitialPoints', ...
        ['Only %d violating points were found after %d deterministic ' ...
        'LHS batches. This problem/design combination cannot supply the ' ...
        'requested %d-point all-infeasible stress design.'], ...
        size(X, 1), maxBatches, pointCount);
end
X = X(1:pointCount, :);
end

function unitX = randomizedLhs(pointCount, dimension)
% One independently permuted, uniformly jittered stratum per dimension.
unitX = zeros(pointCount, dimension);
for dimensionIndex = 1:dimension
    stratumOrder = randperm(pointCount).';
    withinStratum = rand(pointCount, 1);
    unitX(:, dimensionIndex) = ...
        (stratumOrder - 1 + withinStratum) ./ pointCount;
end
end

function corners = allCorners(dimension)
cornerIndex = (0:(2 ^ dimension - 1)).';
corners = dec2bin(cornerIndex, dimension) - '0';
end

function X = scaleFromUnit(unitX, lowerBound, upperBound)
X = unitX .* (upperBound - lowerBound) + lowerBound;
end

function value = optionValue(options, fieldName, defaultValue)
if isfield(options, fieldName) && ~isempty(options.(fieldName))
    value = options.(fieldName);
else
    value = defaultValue;
end
end

function validateProblem(problem)
requiredFields = {'dimension', 'lowerBound', 'upperBound', 'feasible'};
missing = requiredFields(~isfield(problem, requiredFields));
if ~isempty(missing)
    error('cTSEMO:InvalidBenchmarkProblem', ...
        'Problem struct is missing field(s): %s.', strjoin(missing, ', '));
end
validateattributes(problem.dimension, {'numeric'}, ...
    {'scalar', 'integer', 'positive', 'finite'});
validateattributes(problem.lowerBound, {'numeric'}, ...
    {'row', 'numel', problem.dimension, 'finite'});
validateattributes(problem.upperBound, {'numeric'}, ...
    {'row', 'numel', problem.dimension, 'finite'});
if any(problem.upperBound <= problem.lowerBound)
    error('cTSEMO:InvalidBenchmarkBounds', ...
        'Every upper bound must exceed its lower bound.');
end
if ~isa(problem.feasible, 'function_handle')
    error('cTSEMO:InvalidBenchmarkProblem', ...
        'problem.feasible must be a function handle.');
end
end
