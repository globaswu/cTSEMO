function [record, summary, info] = loadIterationDiagnostic(result, iterationIndex)
%LOADITERATIONDIAGNOSTIC Load an iteration summary and optional full record.

    arguments
        result (1,1) struct
        iterationIndex double = []
    end

    [iterations, found] = diagnosticGet(result, "iterations", []);
    if ~found || isempty(iterations)
        error("cTSEMO:Diagnostics:MissingIterations", ...
            "The result does not contain an iterations history.");
    end

    numberOfIterations = iterationCount(iterations);
    if isempty(iterationIndex)
        iterationIndex = numberOfIterations;
    end
    validateattributes(iterationIndex, {'numeric'}, ...
        {'scalar', 'integer', 'positive', '<=', numberOfIterations}, ...
        mfilename, "iterationIndex");

    summary = selectIteration(iterations, iterationIndex);
    [loggedNumber, hasLoggedNumber] = diagnosticGet( ...
        summary, ["iteration", "iterationIndex"], iterationIndex);
    if ~(hasLoggedNumber && isnumeric(loggedNumber) && isscalar(loggedNumber))
        loggedNumber = iterationIndex;
    end

    info = struct( ...
        "iterationIndex", iterationIndex, ...
        "loggedIteration", double(loggedNumber), ...
        "mode", "summary", ...
        "fullRecordFile", "", ...
        "note", "Only the iteration summary was available.");
    record = summary;

    explicitPaths = [ ...
        "fullRecordFile", "fullDiagnosticFile", "diagnosticFile", ...
        "logging.fullRecordFile", "files.fullRecord"];
    [explicitFile, hasExplicitFile] = diagnosticGet(summary, explicitPaths, "");
    candidateFiles = strings(0, 1);
    if hasExplicitFile && (ischar(explicitFile) || isstring(explicitFile))
        candidateFiles(end + 1, 1) = string(explicitFile);
    end

    directories = diagnosticDirectories(result);
    fileNames = [ ...
        compose("online_iteration_%04d_full.mat", double(loggedNumber)); ...
        compose("iteration_%04d_full.mat", double(loggedNumber))];
    for fileName = transpose(fileNames)
        candidateFiles = [candidateFiles; ...
            fullfile(directories, fileName)]; %#ok<AGROW>
    end
    candidateFiles = unique(candidateFiles(candidateFiles ~= ""), "stable");

    for file = transpose(candidateFiles)
        if isfile(file)
            loaded = load(file);
            fullRecord = unwrapLoadedRecord(loaded);
            record = mergeSummary(fullRecord, summary);
            info.mode = "full";
            info.fullRecordFile = string(file);
            info.note = "Loaded the immutable full iteration record.";
            return
        end
    end
end

function count = iterationCount(iterations)
    if isstruct(iterations)
        count = numel(iterations);
    elseif iscell(iterations)
        count = numel(iterations);
    elseif istable(iterations)
        count = height(iterations);
    else
        error("cTSEMO:Diagnostics:InvalidIterations", ...
            "result.iterations must be a struct array, cell array, or table.");
    end
end

function iteration = selectIteration(iterations, index)
    if isstruct(iterations)
        iteration = iterations(index);
    elseif iscell(iterations)
        iteration = iterations{index};
    else
        iteration = table2struct(iterations(index, :), "ToScalar", true);
    end

    if ~(isstruct(iteration) && isscalar(iteration))
        error("cTSEMO:Diagnostics:InvalidIterationRecord", ...
            "Each iteration record must resolve to a scalar structure.");
    end
end

function directories = diagnosticDirectories(result)
    candidates = [ ...
        "options.logging.directory", ...
        "meta.loggingDirectory", ...
        "meta.outputDirectory", ...
        "meta.runDirectory"];
    directories = strings(0, 1);
    for path = candidates
        [value, found] = diagnosticGet(result, path, "");
        if found && (ischar(value) || isstring(value)) && strlength(string(value)) > 0
            directories(end + 1, 1) = string(value); %#ok<AGROW>
        end
    end
    directories = unique(directories, "stable");
end

function record = unwrapLoadedRecord(loaded)
    preferred = [ ...
        "fullRecord", "iterationRecord", "record", "diagnostics", ...
        "iterationData"];
    [record, found] = diagnosticGet(loaded, preferred, []);
    if found && isstruct(record) && isscalar(record)
        return
    end

    names = string(fieldnames(loaded));
    if isscalar(names)
        candidate = loaded.(names);
        if isstruct(candidate) && isscalar(candidate)
            record = candidate;
            return
        end
    end

    record = loaded;
end

function merged = mergeSummary(record, summary)
    if ~(isstruct(record) && isscalar(record))
        error("cTSEMO:Diagnostics:InvalidFullRecord", ...
            "The full iteration MAT-file must contain a scalar structure.");
    end

    merged = record;
    names = string(fieldnames(summary));
    for name = transpose(names)
        if ~isfield(merged, name)
            merged.(name) = summary.(name);
        end
    end
end
