function [figureHandle, metrics, metadata] = ...
        plotWeldedBeamPilotComparison(result, competitorFiles, options)
%PLOTWELDEDBEAMPILOTCOMPARISON Plot an explicitly unmatched WB pilot overlay.
%   [FIGUREHANDLE,METRICS,METADATA] =
%   PLOTWELDEDBEAMPILOTCOMPARISON(RESULT,COMPETITORFILES) reads the supplied
%   CSV files and overlays their objective vectors with the shipped cTSEMO
%   result. This function intentionally computes no solver ranking.
%
%   Every CSV must contain the requested two objective columns (default f1
%   and f2). File paths are always passed explicitly; no competitor result
%   directories are embedded in this function.
%
%   Name-value options:
%     Names             display names; default CSV file stems
%     ObjectiveColumns  one [f1 f2] pair or one pair per CSV
%     Problem           welded-beam metadata for axis labels
%     ComparisonNote    explicit information/budget matching caveat
%     OutputFile        optional export path
%     Resolution        raster export resolution (default 300 dpi)

    arguments
        result (1,1) struct
        competitorFiles
        options.Names = strings(0, 1)
        options.ObjectiveColumns string = ["f1", "f2"]
        options.Problem (1,1) struct = struct()
        options.ComparisonNote (1,1) string = ...
            "Exploratory unmatched runs; no solver ranking is performed."
        options.OutputFile (1,1) string = ""
        options.Resolution (1,1) double {mustBePositive, mustBeFinite} = 300
    end

    files = reshape(string(competitorFiles), [], 1);
    if isempty(files)
        error("cTSEMO:Diagnostics:NoCompetitorFiles", ...
            "At least one explicit competitor CSV path is required.");
    end
    if any(files == "")
        error("cTSEMO:Diagnostics:EmptyCompetitorPath", ...
            "Competitor CSV paths must not be empty.");
    end
    for file = transpose(files)
        if ~isfile(file)
            error("cTSEMO:Diagnostics:MissingCompetitorFile", ...
                "Competitor CSV file not found: %s", file);
        end
    end

    names = canonicalNames(files, options.Names);
    objectiveColumns = canonicalColumnPairs( ...
        options.ObjectiveColumns, numel(files));
    comparators = repmat(struct( ...
        "Name", "", "Y", zeros(0, 2), "Source", ""), numel(files), 1);
    fileSummary = table( ...
        files, names, strings(numel(files), 1), ...
        strings(numel(files), 1), zeros(numel(files), 1), ...
        'VariableNames', { ...
        'File', 'Name', 'Objective1Column', 'Objective2Column', ...
        'FinitePointCount'});

    for index = 1:numel(files)
        data = readtable(files(index), "VariableNamingRule", "preserve");
        [column1, column2] = resolveObjectiveColumns( ...
            data, objectiveColumns(index, :), files(index));
        Y = [data.(column1), data.(column2)];
        if ~isnumeric(Y)
            error("cTSEMO:Diagnostics:NonNumericCompetitorObjective", ...
                "Objective columns in %s must be numeric.", files(index));
        end
        Y = double(Y);
        Y = Y(all(isfinite(Y), 2), :);
        if isempty(Y)
            error("cTSEMO:Diagnostics:EmptyCompetitorFront", ...
                "No finite objective pairs were found in %s.", files(index));
        end

        comparators(index).Name = names(index);
        comparators(index).Y = Y;
        comparators(index).Source = files(index);
        fileSummary.Objective1Column(index) = column1;
        fileSummary.Objective2Column(index) = column2;
        fileSummary.FinitePointCount(index) = size(Y, 1);
    end

    [figureHandle, paretoMetrics, paretoMetadata] = plotParetoFront( ...
        result, ...
        "Problem", options.Problem, ...
        "ComparatorFronts", comparators, ...
        "ShowInfeasible", false, ...
        "Title", "Welded-beam exploratory Pareto overlay (unmatched runs)", ...
        "Subtitle", ...
        "Unequal information; unmatched runs; exploratory only; no ranking.");

    metrics = paretoMetrics;
    metrics.competitorFiles = fileSummary;
    metrics.rankingPerformed = false;

    metadata = paretoMetadata;
    metadata.figureType = "welded-beam unmatched pilot comparison";
    metadata.comparisonStatus = "exploratory and unmatched";
    metadata.comparisonNote = options.ComparisonNote;
    metadata.rankingPerformed = false;
    metadata.caption = ...
        "Exploratory welded-beam Pareto-front overlay using explicitly " + ...
        "supplied CSV files. The plotted runs are not assumed to have " + ...
        "matched initial designs, seeds, budgets, implementations, or " + ...
        "constraint information. The figure supports visual provenance " + ...
        "checking only and performs no solver ranking, including for PAC-MOO. " + ...
        options.ComparisonNote;
    metadata.competitorFiles = fileSummary;

    exportDiagnosticFigure( ...
        figureHandle, options.OutputFile, options.Resolution);
end

function names = canonicalNames(files, requested)
    requested = reshape(string(requested), [], 1);
    if isempty(requested)
        names = strings(numel(files), 1);
        for index = 1:numel(files)
            [~, stem] = fileparts(files(index));
            names(index) = string(stem);
        end
        return
    end
    if numel(requested) ~= numel(files) || any(requested == "")
        error("cTSEMO:Diagnostics:CompetitorNameCount", ...
            "Names must contain one nonempty display name per CSV file.");
    end
    names = requested;
end

function pairs = canonicalColumnPairs(requested, fileCount)
    if isequal(size(requested), [1, 2])
        pairs = repmat(requested, fileCount, 1);
    elseif isequal(size(requested), [fileCount, 2])
        pairs = requested;
    else
        error("cTSEMO:Diagnostics:ObjectiveColumnShape", ...
            "ObjectiveColumns must be a 1-by-2 string pair or one " + ...
            "fileCount-by-2 pair per CSV.");
    end
end

function [column1, column2] = resolveObjectiveColumns( ...
        data, requested, file)
    names = string(data.Properties.VariableNames);
    match1 = find(strcmpi(names, requested(1)), 1);
    match2 = find(strcmpi(names, requested(2)), 1);
    if isempty(match1) || isempty(match2)
        error("cTSEMO:Diagnostics:MissingObjectiveColumns", ...
            "CSV %s does not contain objective columns '%s' and '%s'.", ...
            file, requested(1), requested(2));
    end
    column1 = names(match1);
    column2 = names(match2);
end
