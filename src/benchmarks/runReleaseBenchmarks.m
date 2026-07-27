function [summaryTable, campaignDirectory] = ...
        runReleaseBenchmarks(caseIds, campaignOptions)
%RUNRELEASEBENCHMARKS Execute the frozen, time-bounded release campaign.
%   [SUMMARY, DIRECTORY] = RUNRELEASEBENCHMARKS() runs:
%     COSSIN1     20 initial + 30 sequential evaluations
%     COSSIN2     20 initial + 60 sequential evaluations
%     BNH         10 initial + 30 sequential evaluations
%     BNH_STRESS  10 engineered-infeasible + 20 sequential evaluations
%     SRN         10 initial + 30 sequential evaluations
%     C2DTLZ2     15 initial + 45 sequential evaluations
%
%   The welded-beam 20+130 case is disabled by default. Enable it with:
%
%     options = struct("IncludeWeldedBeam", true);
%     runReleaseBenchmarks([], options);
%
%   A subset can be selected explicitly:
%
%     runReleaseBenchmarks(["COSSIN2", "BNH_STRESS"]);
%
%   CAMPAIGNOPTIONS supports:
%     OutputRoot          parent output folder; default benchmarks/results
%     IncludeWeldedBeam   append WB to the default selection; default false
%     ContinueOnFailure   continue after a failed case; default true
%
%   Scientific/runtime settings are intentionally frozen across cases:
%   1,024 primary candidates, 512 challenger candidates, and 256 objective
%   random Fourier features. COSSIN2 stores full online records; the other
%   cases store summary records. No figures are produced.
%
%   BNH_STRESS is an engineered all-infeasible initialization for fallback
%   diagnostics. It is not an ordinary random replicate and must not be
%   pooled with BNH when reporting optimizer performance.

narginchk(0, 2);
if nargin < 1
    caseIds = [];
end
if nargin < 2 || isempty(campaignOptions)
    campaignOptions = struct();
end

settings = parseCampaignOptions(campaignOptions);
definitions = benchmarkDefinitions();
selected = selectCases(definitions, caseIds, ...
    settings.IncludeWeldedBeam);

releaseRoot = fileparts(fileparts(mfilename('fullpath')));
previousPath = path;
restorePath = onCleanup(@() path(previousPath));
addpath(releaseRoot);
addpath(fullfile(releaseRoot, 'benchmarks'));

if exist('cTSEMO', 'file') ~= 2 || exist('cTSEMOOptions', 'file') ~= 2
    error('cTSEMO:Benchmark:ReleaseNotOnPath', ...
        'The shipped cTSEMO.m and cTSEMOOptions.m are required.');
end
outputParent = settings.OutputRoot;
if strlength(outputParent) == 0
    outputParent = string(fullfile(fileparts(mfilename('fullpath')), ...
        'results'));
end
ensureDirectory(outputParent);

campaignId = "release_benchmark_" + ...
    string(datetime('now'), 'yyyyMMdd_HHmmss_SSS');
campaignDirectory = uniqueSubdirectory(outputParent, campaignId);
ensureDirectory(campaignDirectory);
sourceSeal = sealReleaseSourceManifest(releaseRoot, campaignDirectory);

commonOverrides = frozenRuntimeOverrides();
campaign = struct();
campaign.Id = campaignId;
campaign.Status = "running";
campaign.StartedAt = timestampNow();
campaign.FinishedAt = "";
campaign.Directory = "@CAMPAIGN_ROOT@";
campaign.CaseIds = string({selected.Id}).';
campaign.IncludeWeldedBeam = settings.IncludeWeldedBeam;
campaign.ContinueOnFailure = settings.ContinueOnFailure;
campaign.NumericCsvFormat = "%.17g";
campaign.SourceManifestPath = sourceSeal.ManifestPath;
campaign.SourceManifestRelativePath = sourceSeal.ManifestRelativePath;
campaign.SourceManifestSHA256 = sourceSeal.ManifestSHA256;
campaign.SourceManifestHashPath = sourceSeal.HashPath;
campaign.SourceManifestFileCount = sourceSeal.FileCount;
campaign.SourceManifestTestArtifactCount = ...
    sourceSeal.TestArtifactCount;
campaign.SourceAuthority = sourceSeal.AuthorityStatement;
campaign.HypervolumeReferencePolicy = ...
    "Solver-derived final-feasible reference; not cross-run fixed.";
campaign.Notes = [ ...
    "This is a time-bounded release campaign. BNH_STRESS is an " ...
    "engineered fallback diagnostic, not a random benchmark replicate."];
caseManifests = repmat(emptyCaseManifest(), numel(selected), 1);
saveCampaignManifest(campaignDirectory, campaign, selected, ...
    commonOverrides, caseManifests);

for caseIndex = 1:numel(selected)
    definition = selected(caseIndex);
    problem = getBenchmarkProblem(definition.ProblemId);
    caseFolderName = sprintf('%02d_%s', caseIndex, definition.Id);
    caseRoot = fullfile(campaignDirectory, caseFolderName);
    ensureDirectory(caseRoot);

    designOptions = struct( ...
        'IncludeCorners', ~definition.AllInfeasible, ...
        'AllInfeasible', definition.AllInfeasible);
    [X0, designInfo] = initialDesign(problem, ...
        definition.InitialCount, definition.InitialSeed, designOptions);
    Y0 = problem.objective(X0);
    G0 = problem.constraintMargins(X0);
    label01 = problem.label01(X0);
    binaryConstraint = problem.binaryConstraint(X0);
    C0 = label01;

    if definition.AllInfeasible && any(label01 ~= 0)
        error('cTSEMO:Benchmark:StressInitializationFailed', ...
            '%s was requested as all-infeasible but contains feasibility.', ...
            definition.Id);
    end

    loggingOverrides = struct( ...
        'level', definition.LoggingLevel, ...
        'directory', string(caseRoot), ...
        'checkpoint', false, ...
        'saveEveryIteration', true);
    caseOverrides = mergeStruct(commonOverrides, struct( ...
        'maxEvaluations', definition.SequentialBudget, ...
        'seed', definition.SolverSeed, ...
        'feasibility', struct('inputEncoding', ...
        'feasibleIsOne'), ...
        'logging', loggingOverrides));
    options = cTSEMOOptions(caseOverrides);

    manifest = makeCaseManifest(campaign, definition, problem, ...
        caseIndex, caseRoot, designInfo, options);
    caseManifests(caseIndex) = manifest;
    saveCaseLaunchArtifacts(caseRoot, manifest, options, problem, ...
        X0, Y0, G0, label01, binaryConstraint, C0, designInfo);
    saveCampaignManifest(campaignDirectory, campaign, selected, ...
        commonOverrides, caseManifests);

    caseTimer = tic;
    try
        result = cTSEMO(problem.objective, ...
            problem.label01, X0, Y0, C0, ...
            problem.lowerBound, problem.upperBound, options);
        campaignElapsedSeconds = toc(caseTimer);
        expectedCount = definition.InitialCount + ...
            definition.SequentialBudget;
        if size(result.data.X, 1) ~= expectedCount
            error('cTSEMO:Benchmark:EvaluationCountMismatch', ...
                '%s returned %d points; the protocol requires %d.', ...
                definition.Id, size(result.data.X, 1), expectedCount);
        end
        trueFeasible = problem.feasible(result.data.X);
        if ~isequal(trueFeasible, logical(result.data.isFeasible))
            error('cTSEMO:Benchmark:TruthLabelMismatch', ...
                '%s stored feasibility labels disagree with exact truth.', ...
                definition.Id);
        end

        runDirectory = char(result.meta.outputDirectory);
        if ~isfolder(runDirectory)
            error('cTSEMO:Benchmark:RunDirectoryMissing', ...
                'The solver output folder was not created: %s', ...
                runDirectory);
        end
        resultFile = fullfile(runDirectory, 'result.mat');
        portableRunDirectory = manifest.CaseRoot + "/" + ...
            string(getLastPathPart(runDirectory));
        result.meta.outputDirectory = portableRunDirectory;
        result.options.logging.directory = "@CASE_ROOT@";
        save(resultFile, 'result', '-v7');

        [timing, timingTotals] = extractTiming(result.iterations);
        manifest.Status = "completed";
        manifest.FinishedAt = timestampNow();
        manifest.ElapsedSeconds = campaignElapsedSeconds;
        manifest.RunDirectory = portableRunDirectory;
        manifest.ResultFile = portableRunDirectory + "/result.mat";
        manifest.CompletedSequentialEvaluations = ...
            result.meta.completedEvaluations;
        caseManifests(caseIndex) = manifest;

        saveCaseCompletionArtifacts(runDirectory, manifest, options, ...
            problem, X0, Y0, G0, label01, binaryConstraint, C0, ...
            designInfo, ...
            result, timing, timingTotals);
        saveCaseManifest(caseRoot, manifest);
        clear result
    catch exception
        manifest.Status = "failed";
        manifest.FinishedAt = timestampNow();
        manifest.ElapsedSeconds = toc(caseTimer);
        manifest.ErrorIdentifier = string(exception.identifier);
        manifest.ErrorMessage = string(exception.message);
        failedRunDirectory = newestSubdirectory(caseRoot);
        if strlength(failedRunDirectory) > 0
            manifest.RunDirectory = manifest.CaseRoot + "/" + ...
                string(getLastPathPart(failedRunDirectory));
            manifest.ResultFile = manifest.RunDirectory + "/result.mat";
        end
        caseManifests(caseIndex) = manifest;
        saveCaseManifest(caseRoot, manifest);
        if strlength(failedRunDirectory) > 0
            saveCaseManifest(failedRunDirectory, manifest);
        end
        saveCampaignManifest(campaignDirectory, campaign, selected, ...
            commonOverrides, caseManifests);
        if ~settings.ContinueOnFailure
            rethrow(exception)
        end
        warning('cTSEMO:Benchmark:CaseFailed', ...
            'Case %s failed: %s', definition.Id, exception.message);
    end

    saveCampaignManifest(campaignDirectory, campaign, selected, ...
        commonOverrides, caseManifests);
end

campaign.Status = campaignStatus(caseManifests);
campaign.FinishedAt = timestampNow();
saveCampaignManifest(campaignDirectory, campaign, selected, ...
    commonOverrides, caseManifests);
summaryTable = summarizeReleaseBenchmarks(campaignDirectory);

clear restorePath
end

function definitions = benchmarkDefinitions()
template = struct( ...
    'Id', '', ...
    'ProblemId', '', ...
    'InitialCount', 0, ...
    'SequentialBudget', 0, ...
    'InitialSeed', 0, ...
    'SolverSeed', 0, ...
    'AllInfeasible', false, ...
    'LoggingLevel', "summary", ...
    'DefaultEnabled', true);

definitions = repmat(template, 7, 1);
definitions(1) = makeDefinition( ...
    'COSSIN1', 'COSSIN1', 20, 30, 2026072401, 2026072501, ...
    false, "summary", true);
definitions(2) = makeDefinition( ...
    'COSSIN2', 'COSSIN2', 20, 60, 2026072402, 2026072502, ...
    false, "full", true);
definitions(3) = makeDefinition( ...
    'BNH', 'BNH', 10, 30, 2026072403, 2026072503, ...
    false, "summary", true);
definitions(4) = makeDefinition( ...
    'BNH_STRESS', 'BNH', 10, 20, 2026072404, 2026072504, ...
    true, "summary", true);
definitions(5) = makeDefinition( ...
    'SRN', 'SRN', 10, 30, 2026072405, 2026072505, ...
    false, "summary", true);
definitions(6) = makeDefinition( ...
    'C2DTLZ2', 'C2DTLZ2', 15, 45, ...
    2026072407, 2026072507, false, "summary", true);
definitions(7) = makeDefinition( ...
    'WELDEDBEAM', 'WELDEDBEAM', 20, 130, ...
    2026072406, 2026072506, false, "summary", false);
end

function definition = makeDefinition(id, problemId, initialCount, ...
        sequentialBudget, initialSeed, solverSeed, allInfeasible, ...
        loggingLevel, defaultEnabled)
definition = struct( ...
    'Id', id, ...
    'ProblemId', problemId, ...
    'InitialCount', initialCount, ...
    'SequentialBudget', sequentialBudget, ...
    'InitialSeed', initialSeed, ...
    'SolverSeed', solverSeed, ...
    'AllInfeasible', allInfeasible, ...
    'LoggingLevel', loggingLevel, ...
    'DefaultEnabled', defaultEnabled);
end

function selected = selectCases(definitions, caseIds, includeWeldedBeam)
if isempty(caseIds)
    selected = definitions([definitions.DefaultEnabled]);
    if includeWeldedBeam
        selected(end + 1) = definitions(strcmp( ...
            {definitions.Id}, 'WELDEDBEAM'));
    end
    return
end

requested = string(caseIds);
requested = requested(:);
if any(strcmpi(requested, "all"))
    if numel(requested) ~= 1
        error('cTSEMO:Benchmark:AmbiguousAllSelection', ...
            '"all" cannot be combined with individual case identifiers.');
    end
    selected = definitions;
    return
end

normalized = arrayfun(@normalizeCaseId, requested);
if numel(unique(normalized)) ~= numel(normalized)
    error('cTSEMO:Benchmark:DuplicateCase', ...
        'Each benchmark case may be selected only once.');
end

selected = repmat(definitions(1), 0, 1);
available = string({definitions.Id});
availableNormalized = arrayfun(@normalizeCaseId, available);
for index = 1:numel(normalized)
    location = find(availableNormalized == normalized(index), 1);
    if isempty(location)
        error('cTSEMO:Benchmark:UnknownCase', ...
            'Unknown release benchmark case "%s".', requested(index));
    end
    selected(end + 1, 1) = definitions(location); %#ok<AGROW>
end
end

function id = normalizeCaseId(id)
id = upper(regexprep(string(id), '[^A-Za-z0-9]', ''));
switch id
    case {"BNHSTRESS", "BNHZERO", "ZEROBNH"}
        id = "BNHSTRESS";
    case {"WB", "WELDBEAM"}
        id = "WELDEDBEAM";
end
end

function overrides = frozenRuntimeOverrides()
overrides = struct();
overrides.candidates = struct( ...
    'primaryCount', 1024);
overrides.objectiveGP = struct( ...
    'nFeatures', 256);
overrides.challengers = struct( ...
    'enabled', true, ...
    'count', 512);
end

function settings = parseCampaignOptions(options)
validateattributes(options, {'struct'}, {'scalar'}, ...
    mfilename, 'campaignOptions');
defaults = struct( ...
    'OutputRoot', "", ...
    'IncludeWeldedBeam', false, ...
    'ContinueOnFailure', true);
unknown = setdiff(fieldnames(options), fieldnames(defaults));
if ~isempty(unknown)
    error('cTSEMO:Benchmark:UnknownCampaignOption', ...
        'Unknown campaign option(s): %s.', strjoin(unknown, ', '));
end
settings = mergeStruct(defaults, options);
validateattributes(settings.OutputRoot, {'char', 'string'}, ...
    {'scalartext'}, mfilename, 'campaignOptions.OutputRoot');
settings.OutputRoot = string(settings.OutputRoot);
validateattributes(settings.IncludeWeldedBeam, {'logical', 'numeric'}, ...
    {'scalar', 'binary'}, mfilename, ...
    'campaignOptions.IncludeWeldedBeam');
validateattributes(settings.ContinueOnFailure, {'logical', 'numeric'}, ...
    {'scalar', 'binary'}, mfilename, ...
    'campaignOptions.ContinueOnFailure');
settings.IncludeWeldedBeam = logical(settings.IncludeWeldedBeam);
settings.ContinueOnFailure = logical(settings.ContinueOnFailure);
end

function manifest = makeCaseManifest(campaign, definition, problem, ...
        caseIndex, caseRoot, designInfo, options)
manifest = emptyCaseManifest();
manifest.CampaignId = campaign.Id;
manifest.CaseIndex = caseIndex;
manifest.CaseId = string(definition.Id);
manifest.ProblemId = string(definition.ProblemId);
manifest.ProblemName = string(problem.name);
manifest.Status = "running";
manifest.StartedAt = timestampNow();
manifest.CaseRoot = "@CAMPAIGN_ROOT@/" + ...
    string(getLastPathPart(caseRoot));
manifest.InitialCount = definition.InitialCount;
manifest.SequentialBudget = definition.SequentialBudget;
manifest.InitialSeed = definition.InitialSeed;
manifest.SolverSeed = definition.SolverSeed;
manifest.AllInfeasibleStress = definition.AllInfeasible;
manifest.InitialFeasibleCount = designInfo.FeasibleCount;
manifest.InitialViolatingCount = designInfo.ViolatingCount;
manifest.LoggingLevel = string(definition.LoggingLevel);
manifest.PrimaryCandidateCount = options.candidates.primaryCount;
manifest.ChallengerCandidateCount = options.challengers.count;
manifest.ObjectiveFeatureCount = options.objectiveGP.nFeatures;
manifest.NumericCsvFormat = "%.17g";
manifest.SourceManifestPath = campaign.SourceManifestPath;
manifest.SourceManifestRelativePath = ...
    campaign.SourceManifestRelativePath;
manifest.SourceManifestSHA256 = campaign.SourceManifestSHA256;
manifest.SourceManifestHashPath = campaign.SourceManifestHashPath;
manifest.SourceManifestFileCount = ...
    campaign.SourceManifestFileCount;
manifest.SourceManifestTestArtifactCount = ...
    campaign.SourceManifestTestArtifactCount;
manifest.SourceAuthority = campaign.SourceAuthority;
manifest.HypervolumeReference = "Not source-supported; empty in registry.";
manifest.SourceFiles = string(problem.sourceFiles);
if definition.AllInfeasible
    manifest.Notes = [ ...
        "Engineered all-infeasible fallback stress design. " ...
        "Not an ordinary random benchmark replicate."];
else
    manifest.Notes = "Deterministic LHS plus all hyperrectangle corners.";
end
end

function manifest = emptyCaseManifest()
manifest = struct( ...
    'CampaignId', "", ...
    'CaseIndex', 0, ...
    'CaseId', "", ...
    'ProblemId', "", ...
    'ProblemName', "", ...
    'Status', "pending", ...
    'StartedAt', "", ...
    'FinishedAt', "", ...
    'ElapsedSeconds', NaN, ...
    'CaseRoot', "", ...
    'RunDirectory', "", ...
    'ResultFile', "", ...
    'InitialCount', 0, ...
    'SequentialBudget', 0, ...
    'CompletedSequentialEvaluations', 0, ...
    'InitialSeed', 0, ...
    'SolverSeed', 0, ...
    'AllInfeasibleStress', false, ...
    'InitialFeasibleCount', 0, ...
    'InitialViolatingCount', 0, ...
    'LoggingLevel', "", ...
    'PrimaryCandidateCount', 0, ...
    'ChallengerCandidateCount', 0, ...
    'ObjectiveFeatureCount', 0, ...
    'NumericCsvFormat', "%.17g", ...
    'SourceManifestPath', "", ...
    'SourceManifestRelativePath', "", ...
    'SourceManifestSHA256', "", ...
    'SourceManifestHashPath', "", ...
    'SourceManifestFileCount', 0, ...
    'SourceManifestTestArtifactCount', 0, ...
    'SourceAuthority', "", ...
    'HypervolumeReference', "", ...
    'SourceFiles', strings(0, 1), ...
    'Notes', "", ...
    'ErrorIdentifier', "", ...
    'ErrorMessage', "");
end

function saveCaseLaunchArtifacts(directory, manifest, options, problem, ...
        X0, Y0, G0, label01, binaryConstraint, C0, designInfo)
saveCaseManifest(directory, manifest);
options.logging.directory = "@CASE_ROOT@";
save(fullfile(directory, 'options.mat'), 'options', '-v7');
writeJson(fullfile(directory, 'options.json'), options);
publicProblem = publicProblemMetadata(problem);
save(fullfile(directory, 'initial_design.mat'), ...
    'X0', 'Y0', 'G0', 'label01', 'binaryConstraint', 'C0', ...
    'designInfo', ...
    'publicProblem', '-v7');
writeInitialDesignCsv(fullfile(directory, 'initial_design.csv'), ...
    X0, Y0, G0, label01, binaryConstraint);
end

function saveCaseCompletionArtifacts(directory, manifest, options, ...
        problem, X0, Y0, G0, label01, binaryConstraint, C0, designInfo, ...
        result, timing, timingTotals)
saveCaseManifest(directory, manifest);
options.logging.directory = "@CASE_ROOT@";
save(fullfile(directory, 'options.mat'), 'options', '-v7');
writeJson(fullfile(directory, 'options.json'), options);
publicProblem = publicProblemMetadata(problem);
save(fullfile(directory, 'initial_design.mat'), ...
    'X0', 'Y0', 'G0', 'label01', 'binaryConstraint', 'C0', ...
    'designInfo', ...
    'publicProblem', '-v7');
writeInitialDesignCsv(fullfile(directory, 'initial_design.csv'), ...
    X0, Y0, G0, label01, binaryConstraint);
save(fullfile(directory, 'timing.mat'), ...
    'timing', 'timingTotals', '-v7');
writeTimingCsv(fullfile(directory, 'timing.csv'), timing);

X = result.data.X;
Y = result.data.Y;
G = problem.constraintMargins(X);
labels = double(problem.feasible(X));
binaryConstraint = 1 - 2 .* labels;
writeEvaluationCsv(fullfile(directory, 'evaluations.csv'), ...
    X, Y, G, labels, binaryConstraint);
writeSelectionCsv(fullfile(directory, 'selection_history.csv'), result);
end

function publicProblem = publicProblemMetadata(problem)
handleFields = {'objective', 'constraintMargins', 'constraint', ...
    'feasible', 'label01', 'binaryConstraint', 'f', 'g'};
present = handleFields(isfield(problem, handleFields));
publicProblem = rmfield(problem, present);
end

function [timing, totals] = extractTiming(iterations)
fieldNames = { ...
    'objectiveFitSeconds', ...
    'objectiveDrawSeconds', ...
    'pofFitSeconds', ...
    'candidateGenerationSeconds', ...
    'acquisitionSeconds', ...
    'expensiveEvaluationSeconds', ...
    'iterationSeconds'};
iterationCount = numel(iterations);
timing = struct();
timing.Iteration = (1:iterationCount).';
for fieldIndex = 1:numel(fieldNames)
    name = fieldNames{fieldIndex};
    values = zeros(iterationCount, 1);
    for iteration = 1:iterationCount
        values(iteration) = iterations(iteration).timing.(name);
    end
    timing.(name) = values;
end

totals = struct();
for fieldIndex = 1:numel(fieldNames)
    name = fieldNames{fieldIndex};
    totals.(name) = sum(timing.(name));
end
end

function writeInitialDesignCsv(pathValue, ...
        X, Y, G, label01, binaryConstraint)
headers = [prefixedHeaders('x', size(X, 2)), ...
    prefixedHeaders('f', size(Y, 2)), ...
    prefixedHeaders('g', size(G, 2)), ...
    {'feasible_label_01', 'binary_constraint'}];
data = [X, Y, G, label01(:), binaryConstraint(:)];
writeNumericCsv(pathValue, headers, data);
end

function writeEvaluationCsv(pathValue, ...
        X, Y, G, label01, binaryConstraint)
headers = [prefixedHeaders('x', size(X, 2)), ...
    prefixedHeaders('f', size(Y, 2)), ...
    prefixedHeaders('g', size(G, 2)), ...
    {'feasible_label_01', 'binary_constraint'}];
data = [X, Y, G, label01(:), binaryConstraint(:)];
writeNumericCsv(pathValue, headers, data);
end

function headers = prefixedHeaders(prefix, count)
headers = arrayfun(@(index) sprintf('%s_%d', prefix, index), ...
    1:count, 'UniformOutput', false);
end

function writeTimingCsv(pathValue, timing)
headers = {'iteration', 'objective_fit_seconds', ...
    'objective_draw_seconds', 'pof_fit_seconds', ...
    'candidate_generation_seconds', 'acquisition_seconds', ...
    'expensive_evaluation_seconds', 'iteration_seconds'};
data = [timing.Iteration, timing.objectiveFitSeconds, ...
    timing.objectiveDrawSeconds, timing.pofFitSeconds, ...
    timing.candidateGenerationSeconds, timing.acquisitionSeconds, ...
    timing.expensiveEvaluationSeconds, timing.iterationSeconds];
writeNumericCsv(pathValue, headers, data);
end

function writeSelectionCsv(pathValue, result)
fileId = fopen(pathValue, 'w');
if fileId < 0
    error('cTSEMO:Benchmark:CsvOpenFailed', ...
        'Could not open %s for writing.', pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, ['evaluation_index,added_iteration,selection_source,' ...
    'is_feasible\n']);
for row = 1:size(result.data.X, 1)
    fprintf(fileId, '%d,%d,%s,%d\n', ...
        result.data.evaluationIndex(row), ...
        result.data.addedIteration(row), ...
        csvText(result.data.selectionSource(row)), ...
        result.data.isFeasible(row));
end
clear cleanup
end

function writeNumericCsv(pathValue, headers, data)
if size(data, 2) ~= numel(headers)
    error('cTSEMO:Benchmark:CsvColumnMismatch', ...
        'CSV header and numeric data column counts differ.');
end
fileId = fopen(pathValue, 'w');
if fileId < 0
    error('cTSEMO:Benchmark:CsvOpenFailed', ...
        'Could not open %s for writing.', pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', strjoin(headers, ','));
for row = 1:size(data, 1)
    values = arrayfun(@(value) sprintf('%.17g', value), ...
        data(row, :), 'UniformOutput', false);
    fprintf(fileId, '%s\n', strjoin(values, ','));
end
clear cleanup
end

function saveCaseManifest(directory, manifest)
if strlength(string(directory)) == 0
    return
end
ensureDirectory(directory);
save(fullfile(directory, 'case_manifest.mat'), 'manifest', '-v7');
writeJson(fullfile(directory, 'case_manifest.json'), manifest);
end

function saveCampaignManifest(directory, campaign, definitions, ...
        commonOverrides, caseManifests)
save(fullfile(directory, 'campaign_manifest.mat'), ...
    'campaign', 'definitions', 'commonOverrides', ...
    'caseManifests', '-v7');
serializable = struct( ...
    'campaign', campaign, ...
    'definitions', definitions, ...
    'commonOverrides', commonOverrides, ...
    'caseManifests', caseManifests);
writeJson(fullfile(directory, 'campaign_manifest.json'), serializable);
end

function writeJson(pathValue, value)
encoded = jsonencode(value, 'PrettyPrint', true);
fileId = fopen(pathValue, 'w');
if fileId < 0
    error('cTSEMO:Benchmark:JsonOpenFailed', ...
        'Could not open %s for writing.', pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', encoded);
clear cleanup
end

function value = csvText(value)
value = string(value);
value = replace(value, '"', '""');
value = '"' + value + '"';
value = char(value);
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

function ensureDirectory(directory)
if ~isfolder(directory)
    [created, message] = mkdir(directory);
    if ~created
        error('cTSEMO:Benchmark:DirectoryCreationFailed', ...
            'Could not create directory %s: %s', directory, message);
    end
end
end

function directory = uniqueSubdirectory(parent, baseName)
directory = fullfile(parent, baseName);
suffix = 1;
while isfolder(directory)
    directory = fullfile(parent, baseName + "_" + string(suffix));
    suffix = suffix + 1;
end
end

function directory = newestSubdirectory(parent)
listing = dir(parent);
listing = listing([listing.isdir]);
listing = listing(~ismember({listing.name}, {'.', '..'}));
if isempty(listing)
    directory = "";
    return
end
[~, index] = max([listing.datenum]);
directory = string(fullfile(listing(index).folder, ...
    listing(index).name));
end

function name = getLastPathPart(pathValue)
[~, name] = fileparts(pathValue);
end

function value = campaignStatus(manifests)
statuses = string({manifests.Status});
if all(statuses == "completed")
    value = "completed";
elseif any(statuses == "completed")
    value = "completed_with_failures";
else
    value = "failed";
end
end

function value = timestampNow()
value = string(datetime('now', 'TimeZone', 'local'), ...
    'yyyy-MM-dd''T''HH:mm:ss.SSSXXX');
end
