function summaryTable = summarizeReleaseBenchmarks(campaignDirectory)
%SUMMARIZERELEASEBENCHMARKS Summarize an existing release campaign.
%   SUMMARY = SUMMARIZERELEASEBENCHMARKS(DIRECTORY) reads each case manifest
%   and shipped cTSEMO result without rerunning the optimizer. It writes:
%
%     DIRECTORY/campaign_summary.csv
%     DIRECTORY/campaign_summary.mat
%     RUN_DIRECTORY/summary.csv       for each completed case
%
%   Hypervolume is reported with the final solver-derived reference point.
%   It is therefore an internal anytime diagnostic, not a matched cross-run
%   hypervolume unless a separate common reference is applied offline.

narginchk(1, 1);
validateattributes(campaignDirectory, {'char', 'string'}, ...
    {'scalartext'}, mfilename, 'campaignDirectory');
campaignDirectory = char(campaignDirectory);
if ~isfolder(campaignDirectory)
    error('cTSEMO:Benchmark:CampaignDirectoryMissing', ...
        'Campaign directory does not exist: %s', campaignDirectory);
end

manifestFiles = dir(fullfile(campaignDirectory, '*', ...
    'case_manifest.mat'));
if isempty(manifestFiles)
    error('cTSEMO:Benchmark:NoCaseManifests', ...
        'No case manifests were found under %s.', campaignDirectory);
end

rows = repmat(emptySummaryRow(), numel(manifestFiles), 1);
for index = 1:numel(manifestFiles)
    loadedManifest = load(fullfile(manifestFiles(index).folder, ...
        manifestFiles(index).name), 'manifest');
    manifest = loadedManifest.manifest;
    rows(index) = summaryFromManifest(manifest, campaignDirectory);
    if manifest.Status == "completed" && ...
            strlength(manifest.RunDirectory) > 0
        actualRunDirectory = resolveCampaignPath( ...
            manifest.RunDirectory, campaignDirectory);
        writeStructCsv(fullfile(actualRunDirectory, 'summary.csv'), ...
            rows(index));
    end
end

[~, order] = sort([rows.CaseIndex]);
rows = rows(order);
summaryTable = struct2table(rows, 'AsArray', true);
save(fullfile(campaignDirectory, 'campaign_summary.mat'), ...
    'summaryTable', 'rows', '-v7');
writeStructCsv(fullfile(campaignDirectory, ...
    'campaign_summary.csv'), rows);
end

function row = summaryFromManifest(manifest, campaignDirectory)
row = emptySummaryRow();
row.CampaignId = string(manifest.CampaignId);
row.CaseIndex = manifest.CaseIndex;
row.CaseId = string(manifest.CaseId);
row.ProblemId = string(manifest.ProblemId);
row.Status = string(manifest.Status);
row.AllInfeasibleStress = logical(manifest.AllInfeasibleStress);
row.InitialSeed = manifest.InitialSeed;
row.SolverSeed = manifest.SolverSeed;
row.InitialCount = manifest.InitialCount;
row.SequentialBudget = manifest.SequentialBudget;
row.InitialFeasibleCount = manifest.InitialFeasibleCount;
row.LoggingLevel = string(manifest.LoggingLevel);
row.PrimaryCandidateCount = manifest.PrimaryCandidateCount;
row.ChallengerCandidateCount = manifest.ChallengerCandidateCount;
row.ObjectiveFeatureCount = manifest.ObjectiveFeatureCount;
row.RunDirectory = string(manifest.RunDirectory);
row.ErrorIdentifier = string(manifest.ErrorIdentifier);
row.ErrorMessage = string(manifest.ErrorMessage);

resultFile = string(manifest.ResultFile);
if manifest.Status ~= "completed" || ...
        strlength(resultFile) == 0
    return
end
actualResultFile = resolveCampaignPath(resultFile, campaignDirectory);
if ~isfile(actualResultFile)
    return
end

loadedResult = load(actualResultFile, 'result');
result = loadedResult.result;
data = result.data;
iterations = result.iterations;
row.CompletedSequentialEvaluations = result.meta.completedEvaluations;
row.TotalEvaluations = size(data.X, 1);
row.FinalFeasibleCount = nnz(data.isFeasible);
row.FinalFeasibleRate = mean(data.isFeasible);

firstFeasible = find(data.isFeasible, 1);
if ~isempty(firstFeasible)
    row.FirstFeasibleEvaluationIndex = firstFeasible;
    row.SequentialEvaluationsToFirstFeasible = ...
        max(0, firstFeasible - data.nInitial);
end

row.ParetoPointCount = result.pareto.nPoints;
row.FinalHypervolume = result.pareto.hypervolume;
referencePoint = result.pareto.referencePoint;
if ~isempty(referencePoint)
    row.HypervolumeReference1 = referencePoint(1);
    row.HypervolumeReference2 = referencePoint(2);
end
row.HypervolumeReferenceSource = ...
    "derived from final feasible observations";

if ~isempty(iterations)
    row.FallbackCount = nnz([iterations.fallbackUsed]);
    states = string({iterations.selectionState});
    row.FeasibilityDiscoveryCount = ...
        nnz(states == "feasibilityDiscovery");
    sources = string({iterations.selectionSource});
    row.PrimarySelectionCount = nnz(sources == "primary");
    row.ChallengerSelectionCount = nnz(sources == "challenger");
    row.FallbackSelectionCount = nnz(sources == "fallback");
    row.OtherSelectionCount = nnz(~ismember(sources, ...
        ["primary", "challenger", "fallback"]));
    row.MeanIterationSeconds = meanTiming( ...
        iterations, 'iterationSeconds');
    row.MeanPoFFitSeconds = meanTiming( ...
        iterations, 'pofFitSeconds');
    row.MeanObjectiveFitSeconds = meanTiming( ...
        iterations, 'objectiveFitSeconds');
    row.MeanObjectiveDrawSeconds = meanTiming( ...
        iterations, 'objectiveDrawSeconds');
    row.MeanCandidateGenerationSeconds = meanTiming( ...
        iterations, 'candidateGenerationSeconds');
    row.MeanAcquisitionSeconds = meanTiming( ...
        iterations, 'acquisitionSeconds');
    row.MeanExpensiveEvaluationSeconds = meanTiming( ...
        iterations, 'expensiveEvaluationSeconds');
end
row.WallTimeSeconds = result.meta.wallTimeSeconds;
end

function value = meanTiming(iterations, fieldName)
values = arrayfun(@(record) record.timing.(fieldName), iterations);
value = mean(values);
end

function row = emptySummaryRow()
row = struct( ...
    'CampaignId', "", ...
    'CaseIndex', 0, ...
    'CaseId', "", ...
    'ProblemId', "", ...
    'Status', "", ...
    'AllInfeasibleStress', false, ...
    'InitialSeed', 0, ...
    'SolverSeed', 0, ...
    'InitialCount', 0, ...
    'SequentialBudget', 0, ...
    'CompletedSequentialEvaluations', 0, ...
    'TotalEvaluations', 0, ...
    'InitialFeasibleCount', 0, ...
    'FinalFeasibleCount', 0, ...
    'FinalFeasibleRate', NaN, ...
    'FirstFeasibleEvaluationIndex', NaN, ...
    'SequentialEvaluationsToFirstFeasible', NaN, ...
    'ParetoPointCount', 0, ...
    'FinalHypervolume', NaN, ...
    'HypervolumeReference1', NaN, ...
    'HypervolumeReference2', NaN, ...
    'HypervolumeReferenceSource', "", ...
    'FallbackCount', 0, ...
    'FeasibilityDiscoveryCount', 0, ...
    'PrimarySelectionCount', 0, ...
    'ChallengerSelectionCount', 0, ...
    'FallbackSelectionCount', 0, ...
    'OtherSelectionCount', 0, ...
    'WallTimeSeconds', NaN, ...
    'MeanIterationSeconds', NaN, ...
    'MeanPoFFitSeconds', NaN, ...
    'MeanObjectiveFitSeconds', NaN, ...
    'MeanObjectiveDrawSeconds', NaN, ...
    'MeanCandidateGenerationSeconds', NaN, ...
    'MeanAcquisitionSeconds', NaN, ...
    'MeanExpensiveEvaluationSeconds', NaN, ...
    'LoggingLevel', "", ...
    'PrimaryCandidateCount', 0, ...
    'ChallengerCandidateCount', 0, ...
    'ObjectiveFeatureCount', 0, ...
    'RunDirectory', "", ...
    'ErrorIdentifier', "", ...
    'ErrorMessage', "");
end

function actualPath = resolveCampaignPath(pathValue, campaignDirectory)
pathValue = string(pathValue);
token = "@CAMPAIGN_ROOT@";
if startsWith(pathValue, token)
    relativePath = extractAfter(pathValue, strlength(token));
    relativePath = replace(relativePath, '\', '/');
    relativePath = strip(relativePath, 'left', '/');
    relativePath = replace(relativePath, '/', filesep);
    relativePath = replace(relativePath, '\', filesep);
    actualPath = fullfile(campaignDirectory, char(relativePath));
else
    actualPath = char(pathValue);
end
end

function writeStructCsv(pathValue, rows)
headers = fieldnames(rows);
fileId = fopen(pathValue, 'w');
if fileId < 0
    error('cTSEMO:Benchmark:SummaryCsvOpenFailed', ...
        'Could not open %s for writing.', pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', strjoin(headers, ','));
for rowIndex = 1:numel(rows)
    fields = cell(1, numel(headers));
    for column = 1:numel(headers)
        value = rows(rowIndex).(headers{column});
        fields{column} = encodeCsvValue(value);
    end
    fprintf(fileId, '%s\n', strjoin(fields, ','));
end
clear cleanup
end

function encoded = encodeCsvValue(value)
if islogical(value) && isscalar(value)
    encoded = sprintf('%d', value);
elseif isnumeric(value) && isscalar(value)
    encoded = sprintf('%.17g', value);
elseif (ischar(value) || isstring(value)) && isscalar(string(value))
    text = replace(string(value), '"', '""');
    encoded = char('"' + text + '"');
else
    error('cTSEMO:Benchmark:UnsupportedSummaryValue', ...
        'Summary CSV values must be scalar numeric, logical, or text.');
end
end
