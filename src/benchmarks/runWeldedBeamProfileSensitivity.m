function [summaryTable, studyDirectory] = ...
        runWeldedBeamProfileSensitivity(studyOptions)
%RUNWELDEDBEAMPROFILESENSITIVITY Compare two WB150 runtime profiles.
%   This reproducible study uses the official welded-beam initial design,
%   initial seed 2026072406, solver seed 2026072506, and 20+130 budget for
%   both profiles. Both profiles are rerun independently from the identical
%   saved initial design; the shipped-profile run is not reused from the
%   authoritative release campaign:
%
%     shipped: primary 1024, challenger 512, objective RFF 256
%     higher:  primary 2048, challenger 1024, objective RFF 1000
%
%   The study is computational sensitivity only. It is kept outside the
%   authoritative release benchmark table and must not be presented as a
%   solver-superiority comparison.
%
%   STUDYOPTIONS supports:
%     OutputRoot         parent folder; default benchmarks/sensitivity-results
%     ContinueOnFailure  logical scalar; default true

narginchk(0, 1);
if nargin == 0 || isempty(studyOptions)
    studyOptions = struct();
end
settings = parseOptions(studyOptions);

releaseRoot = fileparts(fileparts(mfilename('fullpath')));
previousPath = path;
restorePath = onCleanup(@() path(previousPath));
addpath(releaseRoot);
addpath(fullfile(releaseRoot, 'benchmarks'));

outputParent = settings.OutputRoot;
if strlength(outputParent) == 0
    outputParent = string(fullfile(fileparts(mfilename('fullpath')), ...
        'sensitivity-results'));
end
ensureDirectory(outputParent);
studyId = "welded_beam_profile_sensitivity_" + ...
    string(datetime('now'), 'yyyyMMdd_HHmmss_SSS');
studyDirectory = uniqueSubdirectory(outputParent, studyId);
ensureDirectory(studyDirectory);
sourceSeal = sealReleaseSourceManifest(releaseRoot, studyDirectory);

problem = getBenchmarkProblem('WELDEDBEAM');
initialSeed = 2026072406;
solverSeed = 2026072506;
initialCount = 20;
sequentialBudget = 130;
[X0, designInfo] = initialDesign(problem, initialCount, initialSeed);
Y0 = problem.objective(X0);
G0 = problem.constraintMargins(X0);
label01 = problem.label01(X0);
binaryConstraint = problem.binaryConstraint(X0);
C0 = label01;
save(fullfile(studyDirectory, 'shared_initial_design.mat'), ...
    'X0', 'Y0', 'G0', 'label01', 'binaryConstraint', 'C0', ...
    'designInfo', ...
    'initialSeed', 'solverSeed', '-v7');

[shippedProfile, ~, ~] = ...
    weldedBeamSensitivityProfile("shipped", "");
[higherProfile, ~, ~] = ...
    weldedBeamSensitivityProfile("higher_compute", "");
profiles = [shippedProfile; higherProfile];
study = struct( ...
    'Id', studyId, ...
    'Purpose', ...
    "Computational profile sensitivity only; separate from the " + ...
    "authoritative release benchmark and not evidence of superiority.", ...
    'Status', "running", ...
    'StartedAt', timestampNow(), ...
    'FinishedAt', "", ...
    'Directory', "@STUDY_ROOT@", ...
    'ProblemId', "WELDEDBEAM", ...
    'InitialCount', initialCount, ...
    'SequentialBudget', sequentialBudget, ...
    'InitialSeed', initialSeed, ...
    'SolverSeed', solverSeed, ...
    'SourceManifestPath', ...
    "@STUDY_ROOT@/release_source_manifest.csv", ...
    'SourceManifestSHA256', sourceSeal.ManifestSHA256, ...
    'SourceManifestHashPath', ...
    "@STUDY_ROOT@/release_source_manifest.sha256");

rows = repmat(emptySummary(), numel(profiles), 1);
saveStudyMetadata(studyDirectory, study, profiles, rows);

for profileIndex = 1:numel(profiles)
    profile = profiles(profileIndex);
    profileRoot = fullfile(studyDirectory, char(profile.Id));
    ensureDirectory(profileRoot);
    [parsedProfile, runtimeOptions, portableOptions] = ...
        weldedBeamSensitivityProfile(profile.Id, profileRoot);
    if ~isequal(parsedProfile, profile)
        error('cTSEMO:Sensitivity:ProfileDefinitionMismatch', ...
            'Parsed profile does not match the study manifest.');
    end

    metadata = makeProfileMetadata(study, profile, portableOptions);
    saveProfileMetadata(profileRoot, metadata, portableOptions);
    timer = tic;
    try
        result = cTSEMO(problem.objective, ...
            problem.label01, X0, Y0, C0, ...
            problem.lowerBound, problem.upperBound, runtimeOptions);
        elapsedSeconds = toc(timer);
        actualRunDirectory = char(result.meta.outputDirectory);
        runFolderName = string(getLastPathPart(actualRunDirectory));
        portableRunDirectory = ...
            "@STUDY_ROOT@/" + profile.Id + "/" + runFolderName;
        result.meta.outputDirectory = portableRunDirectory;
        result.options.logging.directory = "@PROFILE_ROOT@";
        resultFile = fullfile(actualRunDirectory, 'result.mat');
        save(resultFile, 'result', '-v7');

        metadata.Status = "completed";
        metadata.FinishedAt = timestampNow();
        metadata.ElapsedSeconds = elapsedSeconds;
        metadata.RunDirectory = portableRunDirectory;
        metadata.ResultFile = portableRunDirectory + "/result.mat";
        metadata.FinalFeasibleCount = nnz(result.data.isFeasible);
        metadata.ParetoPointCount = result.pareto.nPoints;
        metadata.FallbackCount = nnz([result.iterations.fallbackUsed]);
        saveProfileMetadata(profileRoot, metadata, portableOptions);
        saveProfileMetadata(actualRunDirectory, metadata, portableOptions);
        rows(profileIndex) = summaryFromMetadata(metadata);
    catch exception
        metadata.Status = "failed";
        metadata.FinishedAt = timestampNow();
        metadata.ElapsedSeconds = toc(timer);
        metadata.ErrorIdentifier = string(exception.identifier);
        metadata.ErrorMessage = string(exception.message);
        saveProfileMetadata(profileRoot, metadata, portableOptions);
        rows(profileIndex) = summaryFromMetadata(metadata);
        if ~settings.ContinueOnFailure
            rethrow(exception)
        end
        warning('cTSEMO:Sensitivity:ProfileFailed', ...
            'Welded-beam profile %s failed: %s', ...
            profile.Id, exception.message);
    end
    saveStudyMetadata(studyDirectory, study, profiles, rows);
end

statuses = string({rows.Status});
if all(statuses == "completed")
    study.Status = "completed";
elseif any(statuses == "completed")
    study.Status = "completed_with_failures";
else
    study.Status = "failed";
end
study.FinishedAt = timestampNow();
summaryTable = struct2table(rows, 'AsArray', true);
save(fullfile(studyDirectory, 'profile_sensitivity_summary.mat'), ...
    'summaryTable', 'rows', '-v7');
writetable(summaryTable, fullfile(studyDirectory, ...
    'profile_sensitivity_summary.csv'));
saveStudyMetadata(studyDirectory, study, profiles, rows);

clear restorePath
end

function metadata = makeProfileMetadata(study, profile, options)
metadata = struct( ...
    'StudyId', study.Id, ...
    'ProfileId', profile.Id, ...
    'Purpose', study.Purpose, ...
    'Status', "running", ...
    'StartedAt', timestampNow(), ...
    'FinishedAt', "", ...
    'ElapsedSeconds', NaN, ...
    'RunDirectory', "", ...
    'ResultFile', "", ...
    'InitialSeed', study.InitialSeed, ...
    'SolverSeed', study.SolverSeed, ...
    'InitialCount', study.InitialCount, ...
    'SequentialBudget', study.SequentialBudget, ...
    'PrimaryCandidateCount', profile.PrimaryCandidateCount, ...
    'ChallengerCandidateCount', profile.ChallengerCandidateCount, ...
    'ObjectiveFeatureCount', profile.ObjectiveFeatureCount, ...
    'SourceManifestPath', study.SourceManifestPath, ...
    'SourceManifestSHA256', study.SourceManifestSHA256, ...
    'SourceManifestHashPath', study.SourceManifestHashPath, ...
    'PortableOptions', options, ...
    'FinalFeasibleCount', 0, ...
    'ParetoPointCount', 0, ...
    'FallbackCount', 0, ...
    'ErrorIdentifier', "", ...
    'ErrorMessage', "");
end

function row = emptySummary()
row = struct( ...
    'ProfileId', "", ...
    'Status', "pending", ...
    'InitialSeed', 0, ...
    'SolverSeed', 0, ...
    'InitialCount', 0, ...
    'SequentialBudget', 0, ...
    'PrimaryCandidateCount', 0, ...
    'ChallengerCandidateCount', 0, ...
    'ObjectiveFeatureCount', 0, ...
    'FinalFeasibleCount', 0, ...
    'ParetoPointCount', 0, ...
    'FallbackCount', 0, ...
    'ElapsedSeconds', NaN, ...
    'RunDirectory', "", ...
    'SourceManifestSHA256', "", ...
    'Interpretation', ...
    "Computational sensitivity only; not an authoritative benchmark " + ...
    "or superiority comparison.");
end

function row = summaryFromMetadata(metadata)
row = emptySummary();
row.ProfileId = metadata.ProfileId;
row.Status = metadata.Status;
row.InitialSeed = metadata.InitialSeed;
row.SolverSeed = metadata.SolverSeed;
row.InitialCount = metadata.InitialCount;
row.SequentialBudget = metadata.SequentialBudget;
row.PrimaryCandidateCount = metadata.PrimaryCandidateCount;
row.ChallengerCandidateCount = metadata.ChallengerCandidateCount;
row.ObjectiveFeatureCount = metadata.ObjectiveFeatureCount;
row.FinalFeasibleCount = metadata.FinalFeasibleCount;
row.ParetoPointCount = metadata.ParetoPointCount;
row.FallbackCount = metadata.FallbackCount;
row.ElapsedSeconds = metadata.ElapsedSeconds;
row.RunDirectory = metadata.RunDirectory;
row.SourceManifestSHA256 = metadata.SourceManifestSHA256;
end

function saveStudyMetadata(directory, study, profiles, rows)
save(fullfile(directory, 'study_manifest.mat'), ...
    'study', 'profiles', 'rows', '-v7');
writeJson(fullfile(directory, 'study_manifest.json'), ...
    struct('study', study, 'profiles', profiles, 'rows', rows));
end

function saveProfileMetadata(directory, metadata, portableOptions)
save(fullfile(directory, 'profile_manifest.mat'), ...
    'metadata', 'portableOptions', '-v7');
writeJson(fullfile(directory, 'profile_manifest.json'), metadata);
end

function settings = parseOptions(options)
validateattributes(options, {'struct'}, {'scalar'}, ...
    mfilename, 'studyOptions');
defaults = struct('OutputRoot', "", 'ContinueOnFailure', true);
unknown = setdiff(fieldnames(options), fieldnames(defaults));
if ~isempty(unknown)
    error('cTSEMO:Sensitivity:UnknownOption', ...
        'Unknown sensitivity-runner option(s): %s.', ...
        strjoin(unknown, ', '));
end
settings = defaults;
names = fieldnames(options);
for index = 1:numel(names)
    settings.(names{index}) = options.(names{index});
end
validateattributes(settings.OutputRoot, {'char', 'string'}, ...
    {'scalartext'}, mfilename, 'studyOptions.OutputRoot');
validateattributes(settings.ContinueOnFailure, ...
    {'logical', 'numeric'}, {'scalar', 'binary'}, ...
    mfilename, 'studyOptions.ContinueOnFailure');
settings.OutputRoot = string(settings.OutputRoot);
settings.ContinueOnFailure = logical(settings.ContinueOnFailure);
end

function ensureDirectory(directory)
if ~isfolder(directory)
    [created, message] = mkdir(directory);
    if ~created
        error('cTSEMO:Sensitivity:DirectoryCreationFailed', ...
            'Could not create directory %s: %s', directory, message);
    end
end
end

function directory = uniqueSubdirectory(parent, baseName)
directory = fullfile(parent, baseName);
suffix = 1;
while isfolder(directory)
    directory = fullfile(parent, ...
        baseName + "_" + string(suffix));
    suffix = suffix + 1;
end
end

function name = getLastPathPart(pathValue)
[~, name] = fileparts(pathValue);
end

function writeJson(pathValue, value)
encoded = jsonencode(value, 'PrettyPrint', true);
fileId = fopen(pathValue, 'w');
if fileId < 0
    error('cTSEMO:Sensitivity:JsonOpenFailed', ...
        'Could not open %s for writing.', pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', encoded);
clear cleanup
end

function value = timestampNow()
value = string(datetime('now', 'TimeZone', 'local'), ...
    'yyyy-MM-dd''T''HH:mm:ss.SSSXXX');
end
