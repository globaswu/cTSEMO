function results = runSmokeBenchmarks(problemIds, runOptions)
%RUNSMOKEBENCHMARKS Run very small deterministic cTSEMO integration checks.
%   RESULTS = RUNSMOKEBENCHMARKS() runs COSSIN1 and canonical BNH with an
%   LHS-plus-corners initial design and two sequential evaluations.
%
%   RESULTS = RUNSMOKEBENCHMARKS(PROBLEMIDS, RUNOPTIONS) accepts a string,
%   character vector, string array, or cell array of benchmark identifiers.
%   RUNOPTIONS supports:
%     InitialPointCount        minimum count (default 8)
%     SequentialEvaluations   cTSEMO additions (default 2)
%     Seed                    deterministic base seed (default 1)
%     UseAllInfeasibleStress  logical scalar (default false)
%     StressProblemIds        identifiers stressed when enabled
%                             (default {'BNH'})
%     SolverOptions           overrides passed through cTSEMOOptions()
%     StopOnFailure           rethrow the first failure (default true)
%
%   The all-infeasible mode is intended to exercise the no-feasible-point
%   acquisition fallback. It is not a fair random benchmark initialization.
%   This function intentionally does not launch a long benchmark campaign.

narginchk(0, 2);
if nargin < 1 || isempty(problemIds)
    problemIds = {'COSSIN1', 'BNH'};
end
if nargin < 2 || isempty(runOptions)
    runOptions = struct();
end

validateattributes(runOptions, {'struct'}, {'scalar'}, ...
    mfilename, 'runOptions');
allowedOptionFields = {'InitialPointCount', ...
    'SequentialEvaluations', 'Seed', 'UseAllInfeasibleStress', ...
    'StressProblemIds', 'SolverOptions', 'StopOnFailure'};
unknownOptionFields = setdiff(fieldnames(runOptions), ...
    allowedOptionFields);
if ~isempty(unknownOptionFields)
    error('cTSEMO:SmokeUnknownOption', ...
        'Unknown smoke-runner option(s): %s.', ...
        strjoin(unknownOptionFields, ', '));
end
problemIds = cellstr(string(problemIds));
initialPointCount = optionValue(runOptions, 'InitialPointCount', 8);
sequentialEvaluations = optionValue( ...
    runOptions, 'SequentialEvaluations', 2);
seed = optionValue(runOptions, 'Seed', 1);
useAllInfeasibleStress = optionValue( ...
    runOptions, 'UseAllInfeasibleStress', false);
stressProblemIds = cellstr(string(optionValue( ...
    runOptions, 'StressProblemIds', {'BNH'})));
stopOnFailure = optionValue(runOptions, 'StopOnFailure', true);
solverOptionOverrides = optionValue( ...
    runOptions, 'SolverOptions', struct());

validateattributes(initialPointCount, {'numeric'}, ...
    {'scalar', 'integer', 'positive', 'finite'}, ...
    mfilename, 'runOptions.InitialPointCount');
validateattributes(sequentialEvaluations, {'numeric'}, ...
    {'scalar', 'integer', 'positive', 'finite'}, ...
    mfilename, 'runOptions.SequentialEvaluations');
validateattributes(seed, {'numeric'}, ...
    {'scalar', 'integer', 'nonnegative', 'finite'}, ...
    mfilename, 'runOptions.Seed');
validateattributes(useAllInfeasibleStress, {'logical', 'numeric'}, ...
    {'scalar', 'binary'}, mfilename, ...
    'runOptions.UseAllInfeasibleStress');
validateattributes(stopOnFailure, {'logical', 'numeric'}, ...
    {'scalar', 'binary'}, mfilename, 'runOptions.StopOnFailure');
validateattributes(solverOptionOverrides, {'struct'}, {'scalar'}, ...
    mfilename, 'runOptions.SolverOptions');

releaseRoot = fileparts(fileparts(mfilename('fullpath')));
previousPath = path;
restorePath = onCleanup(@() path(previousPath));
addpath(releaseRoot);
addpath(fullfile(releaseRoot, 'benchmarks'));

if exist('cTSEMO', 'file') ~= 2
    error('cTSEMO:SmokeSolverMissing', ...
        'cTSEMO.m is not available at the release root: %s', releaseRoot);
end

resultTemplate = struct( ...
    'ProblemId', '', ...
    'Status', '', ...
    'ElapsedSeconds', NaN, ...
    'InitialPointCount', NaN, ...
    'InitialFeasibleCount', NaN, ...
    'FinalPointCount', NaN, ...
    'FinalFeasibleCount', NaN, ...
    'X', [], ...
    'Y', [], ...
    'C', [], ...
    'XPareto', [], ...
    'YPareto', [], ...
    'Options', struct(), ...
    'SolverResult', struct(), ...
    'ErrorIdentifier', '', ...
    'ErrorMessage', '');
results = repmat(resultTemplate, numel(problemIds), 1);

for problemIndex = 1:numel(problemIds)
    problem = getBenchmarkProblem(problemIds{problemIndex});
    results(problemIndex).ProblemId = problem.id;
    stressThisProblem = logical(useAllInfeasibleStress) && ...
        any(strcmpi(problem.id, stressProblemIds));

    designPointCount = initialPointCount;
    if ~stressThisProblem
        designPointCount = max(designPointCount, 2 ^ problem.dimension);
    end
    designOptions = struct( ...
        'IncludeCorners', ~stressThisProblem, ...
        'AllInfeasible', stressThisProblem);
    problemSeed = double(seed) + problemIndex - 1;
    [X0, designInfo] = initialDesign( ...
        problem, designPointCount, problemSeed, designOptions);
    Y0 = problem.objective(X0);
    C0 = problem.label01(X0);
    solverOptions = makeSolverOptions( ...
        sequentialEvaluations, problemSeed, solverOptionOverrides);

    results(problemIndex).InitialPointCount = size(X0, 1);
    results(problemIndex).InitialFeasibleCount = designInfo.FeasibleCount;
    startTime = tic;
    try
        solverResult = cTSEMO(problem.objective, ...
            problem.label01, ...
            X0, Y0, C0, problem.lowerBound, problem.upperBound, ...
            solverOptions);
        elapsedSeconds = toc(startTime);
        [X, Y, C, feasible, XPareto, YPareto] = ...
            unpackSolverResult(solverResult);
        results(problemIndex).Status = 'passed';
        results(problemIndex).ElapsedSeconds = elapsedSeconds;
        results(problemIndex).FinalPointCount = size(X, 1);
        results(problemIndex).FinalFeasibleCount = nnz(feasible);
        results(problemIndex).X = X;
        results(problemIndex).Y = Y;
        results(problemIndex).C = C;
        results(problemIndex).XPareto = XPareto;
        results(problemIndex).YPareto = YPareto;
        results(problemIndex).Options = solverOptions;
        results(problemIndex).SolverResult = solverResult;
    catch exception
        results(problemIndex).Status = 'failed';
        results(problemIndex).ElapsedSeconds = toc(startTime);
        results(problemIndex).ErrorIdentifier = exception.identifier;
        results(problemIndex).ErrorMessage = exception.message;
        if logical(stopOnFailure)
            rethrow(exception)
        end
    end
end

clear restorePath
end

function options = makeSolverOptions( ...
    sequentialEvaluations, seed, overrides)
if exist('cTSEMOOptions', 'file') ~= 2
    error('cTSEMO:SmokeOptionsMissing', ...
        'cTSEMOOptions.m is not available on the release path.');
end
requiredOverrides = struct( ...
    'maxEvaluations', sequentialEvaluations, ...
    'seed', seed, ...
    'feasibility', struct('inputEncoding', ...
    'feasibleIsOne'));
allOverrides = mergeStruct(overrides, requiredOverrides);
options = cTSEMOOptions(allOverrides);
end

function value = optionValue(options, fieldName, defaultValue)
if isfield(options, fieldName) && ~isempty(options.(fieldName))
    value = options.(fieldName);
else
    value = defaultValue;
end
end

function merged = mergeStruct(base, overrides)
merged = base;
names = fieldnames(overrides);
for index = 1:numel(names)
    name = names{index};
    if isfield(merged, name) && isstruct(merged.(name)) && ...
            isstruct(overrides.(name))
        merged.(name) = mergeStruct(merged.(name), overrides.(name));
    else
        merged.(name) = overrides.(name);
    end
end
end

function [X, Y, C, feasible, XPareto, YPareto] = ...
        unpackSolverResult(result)
if ~(isstruct(result) && isscalar(result) && isfield(result, 'data'))
    error('cTSEMO:SmokeUnexpectedResult', ...
        'cTSEMO must return the documented scalar result struct.');
end

X = requiredDataField(result.data, {'X', 'x'}, 'design matrix');
Y = requiredDataField(result.data, {'Y', 'y'}, 'objective matrix');
if isfield(result.data, 'C')
    C = result.data.C;
elseif isfield(result.data, 'constraintValues')
    C = result.data.constraintValues;
elseif isfield(result.data, 'isFeasible')
    C = 1 - 2 .* double(result.data.isFeasible(:));
else
    error('cTSEMO:SmokeMissingFeasibilityHistory', ...
        'The result data section has no feasibility history.');
end

if isfield(result.data, 'isFeasible')
    feasible = logical(result.data.isFeasible(:));
else
    C = reshape(C, size(C, 1), []);
    feasible = all(isfinite(C) & C <= 0, 2);
end

XPareto = zeros(0, size(X, 2));
YPareto = zeros(0, 2);
if isfield(result, 'pareto') && isstruct(result.pareto)
    if isfield(result.pareto, 'X')
        XPareto = result.pareto.X;
    elseif isfield(result.pareto, 'x')
        XPareto = result.pareto.x;
    end
    if isfield(result.pareto, 'Y')
        YPareto = result.pareto.Y;
    elseif isfield(result.pareto, 'y')
        YPareto = result.pareto.y;
    end
end
end

function value = requiredDataField(data, candidates, description)
for index = 1:numel(candidates)
    if isfield(data, candidates{index})
        value = data.(candidates{index});
        return
    end
end
error('cTSEMO:SmokeMissingDataField', ...
    'The cTSEMO result data section has no %s.', description);
end
