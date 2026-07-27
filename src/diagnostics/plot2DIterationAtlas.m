function [figureHandle, metadata] = plot2DIterationAtlas( ...
        result, iterationIndex, options)
%PLOT2DITERATIONATLAS Plot one two-variable acquisition decomposition.
%   [FIGUREHANDLE,METADATA] = PLOT2DITERATIONATLAS(RESULT,ITERATIONINDEX)
%   plots the two objective Thompson draws, raw feasibility interpolant,
%   clipped feasibility score p_i, sampled HVI, the design- and
%   codomain-space masks, final acquisition, and fallback score.
%
%   Full iteration records are loaded automatically when their immutable
%   MAT-files can be located. Missing fields in summary-only logs are
%   marked as unavailable; they are never numerically reconstructed from
%   unrelated quantities.
%
%   Name-value options:
%     Problem          benchmark/problem struct; its feasible handle is
%                      used only for a truth-boundary overlay
%     GridData         explicit scalar struct containing X and any plotted
%                      component fields
%     GridSize         truth/model evaluation grid size (default 151)
%     OutputFile       optional PDF, SVG, EPS, PNG, TIFF, or JPEG path
%     Resolution       raster export resolution (default 300 dpi)
%     ShowObservations overlay evaluated sites (default true)
%     Title            optional figure title

    arguments
        result (1,1) struct
        iterationIndex double = []
        options.Problem (1,1) struct = struct()
        options.GridData (1,1) struct = struct()
        options.GridSize (1,1) double {mustBeInteger, mustBePositive} = 151
        options.OutputFile (1,1) string = ""
        options.Resolution (1,1) double {mustBePositive, mustBeFinite} = 300
        options.ShowObservations (1,1) logical = true
        options.Title (1,1) string = ""
    end

    [record, summary, loadInfo] = loadIterationDiagnostic( ...
        result, iterationIndex);
    [lowerBound, upperBound] = resolveProblemBounds( ...
        result, options.Problem);
    if numel(lowerBound) ~= 2
        error("cTSEMO:Diagnostics:AtlasRequires2D", ...
            "plot2DIterationAtlas requires exactly two input variables.");
    end

    [gridX, gridAxes] = makeEvaluationGrid( ...
        lowerBound, upperBound, options.GridSize);
    truth = evaluateTruth(options.Problem, gridX);
    data = extractResultData(result);
    componentData = collectComponents( ...
        record, options.GridData, gridX, lowerBound, upperBound);

    labels = [ ...
        "Objective TS draw: f_1", ...
        "Objective TS draw: f_2", ...
        "Raw feasibility GP mean", ...
        "Clipped feasibility score p_i", ...
        "Sampled hypervolume improvement", ...
        "Design-space mask M_X", ...
        "Codomain-space mask M_Y", ...
        "Final acquisition", ...
        "Fallback score"];
    fields = [ ...
        "objective1", "objective2", "rawPof", "pof", "sampledHVI", ...
        "designMask", "codomainMask", "AF", "fallbackScore"];
    fixedLimits = {[], [], [], [0, 1], [], [0, 1], [0, 1], [], []};

    colors = diagnosticPalette();
    figureHandle = figure( ...
        "Visible", "off", ...
        "Color", "white", ...
        "Units", "pixels", ...
        "Position", [100, 100, 1420, 1120]);
    layout = tiledlayout(figureHandle, 3, 3, ...
        "TileSpacing", "compact", "Padding", "compact");

    iterationNumber = loadInfo.loggedIteration;
    titleText = options.Title;
    if titleText == ""
        titleText = compose( ...
            "cTSEMO iteration %d: acquisition decomposition (%s log)", ...
            iterationNumber, loadInfo.mode);
    end
    title(layout, titleText, "Interpreter", "none", "FontWeight", "bold");

    for fieldIndex = 1:numel(fields)
        axesHandle = nexttile(layout);
        field = fields(fieldIndex);
        values = componentData.(field).values;
        points = componentData.(field).X;
        hasFiniteField = ~isempty(values) && ~isempty(points) && ...
            any(isfinite(values) & all(isfinite(points), 2));
        if ~hasFiniteField
            unavailableMessage = ...
                "Not stored in the available iteration record.";
            [fallbackUsed, hasFallbackFlag] = diagnosticGet(summary, ...
                "fallbackUsed", false);
            if field == "fallbackScore" && hasFallbackFlag && ...
                    ~logical(fallbackUsed)
                unavailableMessage = ...
                    "Fallback was not used, so its score was not evaluated.";
            end
            plotUnavailableTile(axesHandle, labels(fieldIndex), ...
                unavailableMessage);
            continue
        end

        drawField(axesHandle, points, values, lowerBound, upperBound);
        hold(axesHandle, "on");
        overlayTruthBoundary(axesHandle, gridAxes, truth);
        if options.ShowObservations
            overlayObservations(axesHandle, data, colors);
        end
        overlaySelectedPoint(axesHandle, summary, record, colors);
        hold(axesHandle, "off");

        axis(axesHandle, "tight");
        xlim(axesHandle, lowerBound(1:1) + [0, upperBound(1) - lowerBound(1)]);
        ylim(axesHandle, lowerBound(2:2) + [0, upperBound(2) - lowerBound(2)]);
        xlabel(axesHandle, variableLabel(options.Problem, 1));
        ylabel(axesHandle, variableLabel(options.Problem, 2));
        title(axesHandle, labels(fieldIndex), "Interpreter", "tex");
        grid(axesHandle, "on");
        axesHandle.GridAlpha = 0.12;
        axesHandle.Layer = "top";
        if ~isempty(fixedLimits{fieldIndex})
            clim(axesHandle, fixedLimits{fieldIndex});
        end
        colorbar(axesHandle);
    end

    metadata = struct();
    metadata.figureType = "two-dimensional iteration atlas";
    metadata.iteration = iterationNumber;
    metadata.logMode = loadInfo.mode;
    metadata.fullRecordFile = loadInfo.fullRecordFile;
    metadata.fieldsAvailable = availableFields(componentData, fields);
    metadata.truthOverlayAvailable = ~isempty(truth);
    metadata.caption = compose( ...
        "Iteration %d acquisition decomposition. Panels show the two " + ...
        "objective Thompson draws, the raw and clipped binary-label " + ...
        "feasibility field, sampled HVI, anti-clustering masks, final " + ...
        "acquisition, and fallback score. Black contours denote supplied " + ...
        "true feasibility boundaries when available; unavailable fields " + ...
        "are explicitly marked.", iterationNumber);
    metadata.source = sourceDescription(result, options.Problem, loadInfo);
    metadata.generatedAt = datetime("now", "TimeZone", "local");

    exportDiagnosticFigure( ...
        figureHandle, options.OutputFile, options.Resolution);
end

function [gridX, axesValues] = makeEvaluationGrid(lb, ub, gridSize)
    x1 = linspace(lb(1), ub(1), gridSize);
    x2 = linspace(lb(2), ub(2), gridSize);
    [X1, X2] = meshgrid(x1, x2);
    gridX = [X1(:), X2(:)];
    axesValues = struct("x1", x1, "x2", x2, ...
        "X1", X1, "X2", X2);
end

function truth = evaluateTruth(problem, gridX)
    truth = [];
    if isempty(fieldnames(problem))
        return
    end

    [feasibleFunction, found] = diagnosticGet(problem, ...
        ["feasible", "trueFeasibility"], []);
    if found && isa(feasibleFunction, "function_handle")
        values = feasibleFunction(gridX);
        if islogical(values)
            truth = values(:);
        elseif isnumeric(values) && all(isfinite(values), "all") && ...
                all(values == 0 | values == 1, "all")
            truth = logical(values(:));
        else
            error("cTSEMO:Diagnostics:InvalidTruthHandle", ...
                "problem.feasible must return logical or explicit 0/1 values.");
        end
        return
    end

    [constraintFunction, found] = diagnosticGet(problem, ...
        ["constraintMargins", "constraint", "g"], []);
    if found && isa(constraintFunction, "function_handle")
        margins = constraintFunction(gridX);
        truth = all(isfinite(margins) & margins <= 0, 2);
    end
end

function components = collectComponents(record, explicit, gridX, lb, ub)
    components = emptyComponents();
    if ~isempty(fieldnames(explicit))
        components = extractStoredComponents(explicit, components);
    end
    components = extractStoredComponents(record, components);

    [draws, hasDraws] = diagnosticGet(record, ...
        ["objectiveDraws", "models.objectiveDraws", ...
        "full.objectiveDraws"], []);
    if hasDraws
        draws = canonicalDraws(draws);
        queryUnit = (gridX - lb) ./ (ub - lb);
        if numel(draws) >= 1 && isstruct(draws{1}) && ...
                isscalar(draws{1}) && ~isempty(fieldnames(draws{1})) && ...
                isempty(components.objective1.values)
            components.objective1 = component( ...
                gridX, ctsemo.evaluateObjectiveTS(draws{1}, queryUnit));
        end
        if numel(draws) >= 2 && isstruct(draws{2}) && ...
                isscalar(draws{2}) && ~isempty(fieldnames(draws{2})) && ...
                isempty(components.objective2.values)
            components.objective2 = component( ...
                gridX, ctsemo.evaluateObjectiveTS(draws{2}, queryUnit));
        end
    end

    [pofModel, hasPofModel] = diagnosticGet(record, ...
        ["pofModel", "models.pofModel", "full.pofModel"], []);
    if hasPofModel && isstruct(pofModel) && isscalar(pofModel) && ...
            ~isempty(fieldnames(pofModel)) && ...
            isfield(pofModel, "construction")
        queryUnit = (gridX - lb) ./ (ub - lb);
        [pof, rawPof] = evaluatePofModel(pofModel, queryUnit);
        if isempty(components.rawPof.values)
            components.rawPof = component(gridX, rawPof);
        end
        if isempty(components.pof.values)
            components.pof = component(gridX, pof);
        end
    end
end

function [pof, rawPof] = evaluatePofModel(model, XUnit)
    [construction, found] = diagnosticGet(model, "construction", "");
    if found && string(construction) == "constant_all_feasible"
        [rawValue, hasRawValue] = diagnosticGet( ...
            model, "rawValue", 1);
        if ~hasRawValue
            rawValue = 1;
        end
        pof = ones(size(XUnit, 1), 1);
        rawPof = repmat(double(rawValue), size(XUnit, 1), 1);
    else
        [pof, rawPof] = ctsemo.predictClippedBinaryPof(model, XUnit);
    end
end

function components = emptyComponents()
    names = [ ...
        "objective1", "objective2", "rawPof", "pof", "sampledHVI", ...
        "designMask", "codomainMask", "AF", "fallbackScore"];
    components = struct();
    for name = names
        components.(name) = component([], []);
    end
end

function item = component(X, values)
    item = struct("X", double(X), "values", double(values(:)));
end

function components = extractStoredComponents(source, components)
    [X, hasX] = diagnosticGet(source, [ ...
        "X", "grid.X", "candidates.X", "candidateDiagnostics.X", ...
        "full.candidates.X"], []);
    if ~(hasX && isnumeric(X) && size(X, 2) == 2)
        return
    end

    [YDraw, hasYDraw] = diagnosticGet(source, [ ...
        "YDraw", "grid.YDraw", "candidates.YDraw", ...
        "candidateDiagnostics.YDraw", "full.candidates.YDraw"], []);
    if hasYDraw && isnumeric(YDraw) && ...
            size(YDraw, 1) == size(X, 1) && size(YDraw, 2) >= 2
        if isempty(components.objective1.values)
            components.objective1 = component(X, YDraw(:, 1));
        end
        if isempty(components.objective2.values)
            components.objective2 = component(X, YDraw(:, 2));
        end
    end

    map = {
        "rawPof", ["rawPof", "rawMean", "grid.rawPof", ...
            "candidates.rawPof", "candidateDiagnostics.rawPof"];
        "pof", ["pof", "p_i", "grid.pof", "candidates.pof", ...
            "candidateDiagnostics.pof"];
        "sampledHVI", ["sampledHVI", "HVI", "grid.sampledHVI", ...
            "candidates.sampledHVI", "candidateDiagnostics.sampledHVI"];
        "designMask", ["designMask", "Mx", "grid.designMask", ...
            "candidates.designMask", "candidateDiagnostics.designMask"];
        "codomainMask", ["codomainMask", "My", "grid.codomainMask", ...
            "candidates.codomainMask", "candidateDiagnostics.codomainMask"];
        "AF", ["AF", "acquisition", "grid.AF", "candidates.AF", ...
            "candidateDiagnostics.AF"];
        "fallbackScore", ["fallbackScore", "grid.fallbackScore", ...
            "candidates.fallbackScore", ...
            "candidateDiagnostics.fallbackScore"]
        };
    for index = 1:size(map, 1)
        field = map{index, 1};
        if ~isempty(components.(field).values)
            continue
        end
        [values, found] = diagnosticGet(source, map{index, 2}, []);
        if found && isnumeric(values) && numel(values) == size(X, 1)
            components.(field) = component(X, values);
        end
    end
end

function draws = canonicalDraws(value)
    if iscell(value)
        draws = value;
    elseif isstruct(value)
        draws = arrayfun(@(item) item, value, "UniformOutput", false);
    else
        draws = {};
    end
end

function drawField(axesHandle, X, values, lb, ub)
    finite = all(isfinite(X), 2) & isfinite(values);
    X = X(finite, :);
    values = values(finite);
    if isempty(values)
        plotUnavailableTile(axesHandle, "", "No finite values were stored.");
        return
    end

    [isGrid, x1, x2, Z] = regularGrid(X, values);
    if isGrid
        imagesc(axesHandle, x1, x2, Z);
        set(axesHandle, "YDir", "normal");
    else
        markerSize = max(8, min(24, 18000 ./ max(1, size(X, 1))));
        scatter(axesHandle, X(:, 1), X(:, 2), markerSize, values, ...
            "filled", "MarkerEdgeColor", "none");
    end
    xlim(axesHandle, lb([1, 1]) + [0, ub(1) - lb(1)]);
    ylim(axesHandle, lb([2, 2]) + [0, ub(2) - lb(2)]);
    colormap(axesHandle, parula(256));
end

function [isGrid, x1, x2, Z] = regularGrid(X, values)
    x1 = unique(X(:, 1), "sorted");
    x2 = unique(X(:, 2), "sorted");
    isGrid = numel(x1) * numel(x2) == size(X, 1);
    Z = [];
    if ~isGrid
        return
    end

    [isX1, index1] = ismember(X(:, 1), x1);
    [isX2, index2] = ismember(X(:, 2), x2);
    isGrid = all(isX1 & isX2);
    if isGrid
        Z = accumarray([index2, index1], values, ...
            [numel(x2), numel(x1)], @mean, NaN);
        isGrid = all(isfinite(Z), "all");
    end
end

function overlayTruthBoundary(axesHandle, gridAxes, truth)
    if isempty(truth)
        return
    end
    truthGrid = reshape(double(truth), size(gridAxes.X1));
    if all(truthGrid == truthGrid(1), "all")
        return
    end
    contour(axesHandle, gridAxes.X1, gridAxes.X2, truthGrid, ...
        [0.5, 0.5], "Color", [0.08, 0.08, 0.09], ...
        "LineStyle", "--", "LineWidth", 1.1);
end

function overlayObservations(axesHandle, data, colors)
    if isempty(data.X) || size(data.X, 2) ~= 2
        return
    end
    infeasible = ~data.isFeasible;
    scatter(axesHandle, data.X(infeasible, 1), data.X(infeasible, 2), ...
        24, "o", "MarkerEdgeColor", colors.ink, ...
        "MarkerFaceColor", "white", "LineWidth", 0.7);
    scatter(axesHandle, data.X(data.isFeasible, 1), ...
        data.X(data.isFeasible, 2), 24, "o", ...
        "MarkerEdgeColor", colors.ink, ...
        "MarkerFaceColor", colors.gold, "LineWidth", 0.7);
end

function overlaySelectedPoint(axesHandle, summary, record, colors)
    [selectedX, found] = diagnosticGet(summary, ...
        ["selected.X", "selectedX"], []);
    if ~found
        [selectedX, found] = diagnosticGet(record, ...
            ["selected.X", "selectedX"], []);
    end
    if found && isnumeric(selectedX) && numel(selectedX) == 2
        selectedX = reshape(selectedX, 1, 2);
        scatter(axesHandle, selectedX(1), selectedX(2), 72, ...
            "p", "MarkerFaceColor", colors.orange, ...
            "MarkerEdgeColor", colors.ink, "LineWidth", 0.9);
    end
end

function label = variableLabel(problem, variableIndex)
    [names, found] = diagnosticGet(problem, "variableNames", []);
    if found && numel(names) >= variableIndex
        label = string(names{variableIndex});
    else
        label = compose("x_%d", variableIndex);
    end
end

function fields = availableFields(components, names)
    fields = strings(0, 1);
    for name = names
        values = components.(name).values;
        points = components.(name).X;
        if ~isempty(values) && ~isempty(points) && ...
                any(isfinite(values) & all(isfinite(points), 2))
            fields(end + 1, 1) = name; %#ok<AGROW>
        end
    end
end

function description = sourceDescription(result, problem, loadInfo)
    [runId, hasRunId] = diagnosticGet(result, ...
        ["meta.runId", "meta.id"], "");
    [problemId, hasProblemId] = diagnosticGet(problem, ...
        ["id", "name"], "");
    parts = strings(0, 1);
    if hasRunId && strlength(string(runId)) > 0
        parts(end + 1, 1) = "run " + string(runId);
    end
    if hasProblemId && strlength(string(problemId)) > 0
        parts(end + 1, 1) = "problem " + string(problemId);
    end
    if loadInfo.fullRecordFile ~= ""
        parts(end + 1, 1) = loadInfo.fullRecordFile;
    end
    if isempty(parts)
        description = "Supplied cTSEMO result struct.";
    else
        description = strjoin(parts, "; ");
    end
end
