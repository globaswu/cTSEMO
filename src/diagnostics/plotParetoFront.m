function [figureHandle, metrics, metadata] = plotParetoFront(result, options)
%PLOTPARETOFRONT Plot observed and optional comparator objective fronts.
%   [FIGUREHANDLE,METRICS,METADATA] = PLOTPARETOFRONT(RESULT) plots all
%   observed objective vectors, distinguishes binary feasibility without
%   relying on color alone, and highlights the final feasible nondominated
%   front for a two-objective minimization problem.
%
%   ComparatorFronts is an optional struct array. Each element must contain
%   Name and Y; Source is recommended. Comparator data are plotted as
%   supplied and are not interpreted as matched or statistically comparable.
%
%   Name-value options:
%     Problem             problem metadata for axis names and units
%     ComparatorFronts    struct array with Name, Y, and optional Source
%     OutputFile          optional export path
%     Resolution          raster export resolution (default 300 dpi)
%     Title               optional figure title
%     Subtitle            optional figure subtitle
%     ShowInfeasible      show observed infeasible points (default true)
%     ShowReferencePoint  plot the stored HV reference (default false)

    arguments
        result (1,1) struct
        options.Problem (1,1) struct = struct()
        options.ComparatorFronts struct = struct( ...
            "Name", {}, "Y", {}, "Source", {})
        options.OutputFile (1,1) string = ""
        options.Resolution (1,1) double {mustBePositive, mustBeFinite} = 300
        options.Title (1,1) string = ""
        options.Subtitle (1,1) string = ...
            "Both objectives are minimized; comparator fronts are shown as supplied."
        options.ShowInfeasible (1,1) logical = true
        options.ShowReferencePoint (1,1) logical = false
    end

    data = extractResultData(result);
    if size(data.Y, 2) ~= 2
        error("cTSEMO:Diagnostics:ParetoRequiresTwoObjectives", ...
            "plotParetoFront requires a stored two-objective history.");
    end
    finite = all(isfinite(data.Y), 2);
    feasibleY = data.Y(data.isFeasible & finite, :);
    infeasibleY = data.Y(~data.isFeasible & finite, :);
    front = nondominatedFront(feasibleY);
    comparators = canonicalComparators(options.ComparatorFronts);

    colors = diagnosticPalette();
    categoryColors = [ ...
        colors.orange; colors.purple; colors.olive; colors.cyan; colors.gold];
    lineStyles = ["--", ":", "-.", "--", ":"];

    figureHandle = figure( ...
        "Visible", "off", ...
        "Color", "white", ...
        "Units", "pixels", ...
        "Position", [100, 100, 960, 760]);
    axesHandle = axes(figureHandle);
    hold(axesHandle, "on");

    legendHandles = gobjects(0);
    legendLabels = strings(0);
    if options.ShowInfeasible && ~isempty(infeasibleY)
        handle = scatter(axesHandle, ...
            infeasibleY(:, 1), infeasibleY(:, 2), 26, "x", ...
            "MarkerEdgeColor", colors.midGray, "LineWidth", 0.8);
        legendHandles(end + 1) = handle;
        legendLabels(end + 1) = "Observed infeasible";
    end
    if ~isempty(feasibleY)
        handle = scatter(axesHandle, feasibleY(:, 1), feasibleY(:, 2), ...
            26, "o", "MarkerFaceColor", "white", ...
            "MarkerEdgeColor", colors.blue, "LineWidth", 0.7);
        legendHandles(end + 1) = handle;
        legendLabels(end + 1) = "Observed feasible";
    end
    if ~isempty(front)
        front = sortrows(front, [1, 2]);
        handle = plot(axesHandle, front(:, 1), front(:, 2), "-o", ...
            "Color", colors.blue, "MarkerFaceColor", colors.blue, ...
            "MarkerEdgeColor", colors.ink, "MarkerSize", 4.5, ...
            "LineWidth", 1.7);
        legendHandles(end + 1) = handle;
        legendLabels(end + 1) = "cTSEMO feasible nondominated";
    end

    for index = 1:numel(comparators)
        Y = sortrows(comparators(index).Y, [1, 2]);
        color = categoryColors(1 + mod(index - 1, ...
            size(categoryColors, 1)), :);
        lineStyle = lineStyles(1 + mod(index - 1, numel(lineStyles)));
        handle = plot(axesHandle, Y(:, 1), Y(:, 2), ...
            lineStyle, "Color", color, "LineWidth", 1.25, ...
            "Marker", "s", "MarkerSize", 4, ...
            "MarkerFaceColor", "white", "MarkerEdgeColor", color);
        legendHandles(end + 1) = handle; %#ok<AGROW>
        legendLabels(end + 1) = comparators(index).Name; %#ok<AGROW>
    end

    [referencePoint, hasReference] = diagnosticGet(result, ...
        ["pareto.referencePoint", "hypervolume.referencePoint"], []);
    if options.ShowReferencePoint && hasReference && ...
            isnumeric(referencePoint) && numel(referencePoint) == 2 && ...
            all(isfinite(referencePoint), "all")
        handle = scatter(axesHandle, referencePoint(1), referencePoint(2), ...
            70, "d", "MarkerFaceColor", colors.gold, ...
            "MarkerEdgeColor", colors.ink, "LineWidth", 0.8);
        legendHandles(end + 1) = handle;
        legendLabels(end + 1) = "Stored HV reference";
    end

    hold(axesHandle, "off");
    xlabel(axesHandle, objectiveLabel(options.Problem, 1));
    ylabel(axesHandle, objectiveLabel(options.Problem, 2));
    titleText = options.Title;
    if titleText == ""
        titleText = "Two-objective feasible Pareto-front approximation";
    end
    title(axesHandle, titleText, "Interpreter", "none");
    if options.Subtitle ~= ""
        subtitle(axesHandle, options.Subtitle, "Interpreter", "none");
    end
    grid(axesHandle, "on");
    axesHandle.GridAlpha = 0.15;
    axesHandle.Layer = "top";
    if ~isempty(legendHandles)
        legend(axesHandle, legendHandles, legendLabels, ...
            "Location", "best", "Box", "off", "Interpreter", "none");
    end

    metrics = struct();
    metrics.observedCount = size(data.Y, 1);
    metrics.feasibleCount = size(feasibleY, 1);
    metrics.infeasibleCount = size(infeasibleY, 1);
    metrics.front = front;
    metrics.frontCount = size(front, 1);
    metrics.comparatorCount = numel(comparators);

    metadata = struct();
    metadata.figureType = "two-objective Pareto-front comparison";
    if options.ShowInfeasible
        observedDescription = ...
            "Observed objective vectors with binary feasibility labels";
    else
        observedDescription = "Observed feasible objective vectors";
    end
    metadata.caption = compose( ...
        observedDescription + ...
        " and the final feasible nondominated set (%d points). Optional " + ...
        "comparator fronts are provenance overlays only unless the " + ...
        "underlying designs, budgets, seeds, implementations, and " + ...
        "constraint information are matched separately.", size(front, 1));
    metadata.comparators = comparatorMetadata(comparators);
    metadata.source = resultSource(result);
    metadata.generatedAt = datetime("now", "TimeZone", "local");

    exportDiagnosticFigure( ...
        figureHandle, options.OutputFile, options.Resolution);
end

function front = nondominatedFront(Y)
    if isempty(Y)
        front = zeros(0, 2);
        return
    end
    Y = unique(Y, "rows", "stable");
    keep = true(size(Y, 1), 1);
    for index = 1:size(Y, 1)
        dominates = all(Y <= Y(index, :), 2) & ...
            any(Y < Y(index, :), 2);
        if any(dominates)
            keep(index) = false;
        end
    end
    front = Y(keep, :);
end

function comparators = canonicalComparators(input)
    comparators = input;
    for index = 1:numel(comparators)
        if ~isfield(comparators, "Name") || ...
                ~(ischar(comparators(index).Name) || ...
                isstring(comparators(index).Name))
            error("cTSEMO:Diagnostics:ComparatorName", ...
                "Each ComparatorFronts element must contain a text Name.");
        end
        if ~isfield(comparators, "Y")
            error("cTSEMO:Diagnostics:ComparatorData", ...
                "Each ComparatorFronts element must contain Y.");
        end
        Y = comparators(index).Y;
        validateattributes(Y, {'numeric'}, ...
            {'2d', 'ncols', 2, 'real', 'finite', 'nonempty'}, ...
            mfilename, "ComparatorFronts.Y");
        comparators(index).Name = string(comparators(index).Name);
        comparators(index).Y = double(Y);
        if ~isfield(comparators, "Source") || ...
                isempty(comparators(index).Source)
            comparators(index).Source = "";
        else
            comparators(index).Source = string(comparators(index).Source);
        end
    end
end

function label = objectiveLabel(problem, index)
    [names, hasNames] = diagnosticGet(problem, "objectiveNames", []);
    [units, hasUnits] = diagnosticGet(problem, "objectiveUnits", []);
    if hasNames && numel(names) >= index
        name = textAt(names, index);
    else
        name = compose("f_%d", index);
    end
    if hasUnits && numel(units) >= index
        unit = textAt(units, index);
    else
        unit = "";
    end
    if unit == ""
        label = name;
    else
        label = name + " (" + unit + ")";
    end
end

function value = textAt(collection, index)
    if iscell(collection)
        value = string(collection{index});
    else
        value = string(collection(index));
    end
end

function tableOut = comparatorMetadata(comparators)
    names = strings(numel(comparators), 1);
    sources = strings(numel(comparators), 1);
    counts = zeros(numel(comparators), 1);
    for index = 1:numel(comparators)
        names(index) = comparators(index).Name;
        sources(index) = comparators(index).Source;
        counts(index) = size(comparators(index).Y, 1);
    end
    tableOut = table(names, counts, sources, ...
        'VariableNames', {'Name', 'PointCount', 'Source'});
end

function description = resultSource(result)
    [runId, found] = diagnosticGet(result, ["meta.runId", "meta.id"], "");
    if found && strlength(string(runId)) > 0
        description = "Supplied cTSEMO result, run " + string(runId) + ".";
    else
        description = "Supplied cTSEMO result struct.";
    end
end
