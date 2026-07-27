function [figureHandle, metrics, metadata] = plotOptimizationHistory( ...
        result, options)
%PLOTOPTIMIZATIONHISTORY Plot selection, feasibility, and hypervolume history.
%   [FIGUREHANDLE,METRICS,METADATA] = PLOTOPTIMIZATIONHISTORY(RESULT)
%   creates three panels: the logged source of every sequential selection,
%   cumulative feasibility discovery, and two-objective hypervolume using
%   one fixed reference point for the complete curve.
%
%   Name-value options:
%     ReferencePoint  explicit fixed two-objective minimization reference
%     OutputFile      optional export path
%     Resolution      raster export resolution (default 300 dpi)
%     Title           optional figure title

    arguments
        result (1,1) struct
        options.ReferencePoint double = []
        options.OutputFile (1,1) string = ""
        options.Resolution (1,1) double {mustBePositive, mustBeFinite} = 300
        options.Title (1,1) string = ""
    end

    data = extractResultData(result);
    history = extractIterationHistory(result, data.nInitial);
    [referencePoint, referenceSource] = resolveReferencePoint( ...
        result, history, options.ReferencePoint);
    [hypervolume, hypervolumeAvailable] = fixedReferenceHistory( ...
        data.Y, data.isFeasible, referencePoint);

    colors = diagnosticPalette();
    figureHandle = figure( ...
        "Visible", "off", ...
        "Color", "white", ...
        "Units", "pixels", ...
        "Position", [100, 100, 1180, 920]);
    layout = tiledlayout(figureHandle, 3, 1, ...
        "TileSpacing", "compact", "Padding", "compact");

    titleText = options.Title;
    if titleText == ""
        titleText = "cTSEMO optimization history";
    end
    title(layout, titleText, "Interpreter", "none", "FontWeight", "bold");

    selectionAxes = nexttile(layout);
    drawSelectionTimeline(selectionAxes, history, colors);

    feasibilityAxes = nexttile(layout);
    drawFeasibilityHistory(feasibilityAxes, data, colors);

    hypervolumeAxes = nexttile(layout);
    if hypervolumeAvailable
        plot(hypervolumeAxes, 1:numel(hypervolume), hypervolume, ...
            "-o", "Color", colors.blue, "MarkerFaceColor", colors.blue, ...
            "MarkerSize", 3.5, "LineWidth", 1.25);
        hold(hypervolumeAxes, "on");
        drawInitialBoundary(hypervolumeAxes, data.nInitial);
        hold(hypervolumeAxes, "off");
        xlabel(hypervolumeAxes, "Expensive evaluations");
        ylabel(hypervolumeAxes, "Hypervolume");
        title(hypervolumeAxes, ...
            "Feasible-front hypervolume at one fixed reference");
        grid(hypervolumeAxes, "on");
        hypervolumeAxes.GridAlpha = 0.15;
        subtitle(hypervolumeAxes, compose( ...
            "Reference = [%g, %g]; %s", ...
            referencePoint(1), referencePoint(2), referenceSource), ...
            "Interpreter", "none");
    else
        plotUnavailableTile(hypervolumeAxes, ...
            "Feasible-front hypervolume at one fixed reference", ...
            "No valid fixed two-objective reference point was stored or supplied.");
    end

    metrics = struct();
    metrics.evaluation = (1:size(data.X, 1)).';
    metrics.isFeasible = data.isFeasible;
    if isempty(data.isFeasible)
        metrics.cumulativeFeasibilityRate = zeros(0, 1);
    else
        metrics.cumulativeFeasibilityRate = ...
            cumsum(double(data.isFeasible)) ./ (1:numel(data.isFeasible)).';
    end
    metrics.hypervolume = hypervolume;
    metrics.referencePoint = referencePoint;
    metrics.referenceSource = referenceSource;
    metrics.selectionEvaluation = history.evaluationIndex;
    metrics.selectionSource = history.source;
    metrics.fallbackUsed = history.fallbackUsed;
    metrics.fallbackReason = history.fallbackReason;
    metrics.selectionCounts = selectionCounts(history.source);

    metadata = struct();
    metadata.figureType = "optimization history";
    metadata.caption = ...
        "Logged selection source, cumulative feasible-evaluation rate, " + ...
        "and feasible-front hypervolume. The hypervolume curve uses one " + ...
        "reference point for every prefix; the subtitle states whether " + ...
        "that point was supplied or recovered from the run record.";
    metadata.hypervolumeAvailable = hypervolumeAvailable;
    metadata.referencePoint = referencePoint;
    metadata.referenceSource = referenceSource;
    metadata.initialEvaluationCount = data.nInitial;
    metadata.source = resultSource(result);
    metadata.generatedAt = datetime("now", "TimeZone", "local");

    exportDiagnosticFigure( ...
        figureHandle, options.OutputFile, options.Resolution);
end

function history = extractIterationHistory(result, nInitial)
    [iterations, found] = diagnosticGet(result, "iterations", []);
    if ~found || isempty(iterations)
        history = emptyHistory();
        return
    end

    count = iterationCount(iterations);
    evaluationIndex = zeros(count, 1);
    source = strings(count, 1);
    fallbackUsed = false(count, 1);
    fallbackReason = strings(count, 1);

    for index = 1:count
        record = iterationAt(iterations, index);
        [value, hasValue] = diagnosticGet(record, ...
            ["evaluationIndex", "observation.evaluationIndex"], []);
        if hasValue && isnumeric(value) && isscalar(value) && isfinite(value)
            evaluationIndex(index) = double(value);
        else
            evaluationIndex(index) = nInitial + index;
        end

        [value, hasValue] = diagnosticGet(record, ...
            ["selectionSource", "selected.source", "source"], "unlogged");
        if hasValue && (ischar(value) || isstring(value) || iscategorical(value))
            source(index) = string(value);
        else
            source(index) = "unlogged";
        end

        [value, hasValue] = diagnosticGet(record, ...
            ["fallbackUsed", "selected.fallbackUsed"], false);
        if hasValue && (islogical(value) || isnumeric(value)) && isscalar(value)
            fallbackUsed(index) = logical(value);
        end

        [value, hasValue] = diagnosticGet(record, ...
            ["fallbackReason", "selected.fallbackReason"], "");
        if hasValue && (ischar(value) || isstring(value))
            fallbackReason(index) = string(value);
        end
    end

    history = struct( ...
        "evaluationIndex", evaluationIndex, ...
        "source", source, ...
        "fallbackUsed", fallbackUsed, ...
        "fallbackReason", fallbackReason);
end

function count = iterationCount(iterations)
    if istable(iterations)
        count = height(iterations);
    else
        count = numel(iterations);
    end
end

function record = iterationAt(iterations, index)
    if isstruct(iterations)
        record = iterations(index);
    elseif iscell(iterations)
        record = iterations{index};
    elseif istable(iterations)
        record = table2struct(iterations(index, :), "ToScalar", true);
    else
        error("cTSEMO:Diagnostics:InvalidIterations", ...
            "result.iterations must be a struct array, cell array, or table.");
    end
end

function history = emptyHistory()
    history = struct( ...
        "evaluationIndex", zeros(0, 1), ...
        "source", strings(0, 1), ...
        "fallbackUsed", false(0, 1), ...
        "fallbackReason", strings(0, 1));
end

function [referencePoint, source] = resolveReferencePoint( ...
        result, history, supplied)
    if ~isempty(supplied)
        validateReference(supplied);
        referencePoint = reshape(double(supplied), 1, 2);
        source = "supplied explicitly";
        return
    end

    [stored, found] = diagnosticGet(result, ...
        ["pareto.referencePoint", "hypervolume.referencePoint"], []);
    if found && isValidReference(stored)
        referencePoint = reshape(double(stored), 1, 2);
        source = "final stored reference applied to every prefix";
        return
    end

    referencePoint = [];
    source = "not available";
    if isempty(history.evaluationIndex)
        return
    end
end

function validateReference(value)
    if ~isValidReference(value)
        error("cTSEMO:Diagnostics:InvalidReferencePoint", ...
            "ReferencePoint must contain two finite real values.");
    end
end

function valid = isValidReference(value)
    valid = isnumeric(value) && numel(value) == 2 && ...
        isreal(value) && all(isfinite(value), "all");
end

function [history, available] = fixedReferenceHistory(Y, feasible, reference)
    history = zeros(size(Y, 1), 1);
    available = size(Y, 2) == 2 && isValidReference(reference);
    if ~available
        history = NaN(size(Y, 1), 1);
        return
    end

    for evaluation = 1:size(Y, 1)
        selected = feasible(1:evaluation) & ...
            all(isfinite(Y(1:evaluation, :)), 2);
        history(evaluation) = hypervolume2d( ...
            Y(selected, :), reference);
    end
end

function value = hypervolume2d(Y, reference)
    if isempty(Y)
        value = 0;
        return
    end
    Y = Y(all(Y < reference, 2), :);
    if isempty(Y)
        value = 0;
        return
    end

    front = nondominated2d(Y);
    front = sortrows(front, [1, 2]);
    value = 0;
    secondBoundary = reference(2);
    for row = 1:size(front, 1)
        width = max(0, reference(1) - front(row, 1));
        height = max(0, secondBoundary - front(row, 2));
        value = value + width * height;
        secondBoundary = min(secondBoundary, front(row, 2));
    end
end

function front = nondominated2d(Y)
    [sorted, ~] = sortrows(Y, [1, 2]);
    keep = false(size(sorted, 1), 1);
    bestSecond = Inf;
    for row = 1:size(sorted, 1)
        if sorted(row, 2) < bestSecond
            keep(row) = true;
            bestSecond = sorted(row, 2);
        end
    end
    front = sorted(keep, :);
end

function drawSelectionTimeline(axesHandle, history, colors)
    if isempty(history.source)
        plotUnavailableTile(axesHandle, "Sequential point-selection source", ...
            "No iteration selection history was stored.");
        return
    end

    categories = unique(history.source, "stable");
    y = zeros(size(history.source));
    for index = 1:numel(categories)
        y(history.source == categories(index)) = index;
    end

    scatter(axesHandle, history.evaluationIndex(~history.fallbackUsed), ...
        y(~history.fallbackUsed), 42, "o", ...
        "MarkerFaceColor", colors.blue, ...
        "MarkerEdgeColor", colors.ink, "LineWidth", 0.6);
    hold(axesHandle, "on");
    scatter(axesHandle, history.evaluationIndex(history.fallbackUsed), ...
        y(history.fallbackUsed), 62, "d", ...
        "MarkerFaceColor", colors.orange, ...
        "MarkerEdgeColor", colors.ink, "LineWidth", 0.8);
    hold(axesHandle, "off");

    yticks(axesHandle, 1:numel(categories));
    yticklabels(axesHandle, categories);
    ylim(axesHandle, [0.5, numel(categories) + 0.5]);
    xlabel(axesHandle, "Expensive evaluation index");
    ylabel(axesHandle, "Selection source");
    title(axesHandle, "Sequential point-selection source");
    grid(axesHandle, "on");
    axesHandle.GridAlpha = 0.15;
    legend(axesHandle, ["Ordinary selection", "Fallback"], ...
        "Location", "best", "Box", "off");
end

function drawFeasibilityHistory(axesHandle, data, colors)
    if isempty(data.isFeasible)
        plotUnavailableTile(axesHandle, ...
            "Cumulative feasible-evaluation rate", ...
            "No feasibility history was stored.");
        return
    end

    evaluation = (1:numel(data.isFeasible)).';
    cumulativeRate = cumsum(double(data.isFeasible)) ./ evaluation;
    plot(axesHandle, evaluation, cumulativeRate, "-", ...
        "Color", colors.olive, "LineWidth", 1.35);
    hold(axesHandle, "on");
    scatter(axesHandle, evaluation(data.isFeasible), ...
        double(data.isFeasible(data.isFeasible)), 22, "o", ...
        "MarkerFaceColor", colors.gold, ...
        "MarkerEdgeColor", colors.ink, "LineWidth", 0.5);
    scatter(axesHandle, evaluation(~data.isFeasible), ...
        double(data.isFeasible(~data.isFeasible)), 22, "o", ...
        "MarkerFaceColor", "white", ...
        "MarkerEdgeColor", colors.ink, "LineWidth", 0.6);
    drawInitialBoundary(axesHandle, data.nInitial);
    hold(axesHandle, "off");

    ylim(axesHandle, [-0.05, 1.05]);
    xlabel(axesHandle, "Expensive evaluations");
    ylabel(axesHandle, "Rate / binary label");
    title(axesHandle, "Cumulative feasible-evaluation rate");
    legend(axesHandle, ...
        ["Cumulative rate", "Feasible evaluation", ...
        "Infeasible evaluation", "End of initial design"], ...
        "Location", "best", "Box", "off");
    grid(axesHandle, "on");
    axesHandle.GridAlpha = 0.15;
end

function drawInitialBoundary(axesHandle, nInitial)
    if nInitial > 0
        xline(axesHandle, nInitial + 0.5, ":", ...
            "Color", [0.25, 0.25, 0.27], "LineWidth", 1.0);
    end
end

function counts = selectionCounts(source)
    if isempty(source)
        counts = table(strings(0, 1), zeros(0, 1), ...
            'VariableNames', {'Source', 'Count'});
        return
    end
    names = unique(source, "stable");
    number = zeros(numel(names), 1);
    for index = 1:numel(names)
        number(index) = nnz(source == names(index));
    end
    counts = table(names, number, ...
        'VariableNames', {'Source', 'Count'});
end

function description = resultSource(result)
    [runId, found] = diagnosticGet(result, ["meta.runId", "meta.id"], "");
    if found && strlength(string(runId)) > 0
        description = "Supplied cTSEMO result, run " + string(runId) + ".";
    else
        description = "Supplied cTSEMO result struct.";
    end
end
