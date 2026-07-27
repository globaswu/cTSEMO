function [figureHandle, metrics, metadata] = plotPofValidation( ...
        result, options)
%PLOTPOFVALIDATION Diagnose one clipped feasibility-score field.
%   [FIGUREHANDLE,METRICS,METADATA] = PLOTPOFVALIDATION(RESULT) plots
%   conditional empirical CDFs of the same p_i field, ROC/AUC, a reliability
%   diagram, and a threshold confusion matrix. Feasible is the positive
%   class throughout.
%
%   Validation scores and labels can be supplied explicitly with Score and
%   Truth. Otherwise, the function searches the selected iteration's full
%   record for a validation/candidate p_i field. When points and a Problem
%   truth handle are available, labels are evaluated from that handle.
%
%   Name-value options:
%     Iteration         iteration to inspect (default last)
%     Score             explicit clipped p_i values
%     Truth             explicit feasible=true labels
%     Points            design points corresponding to Score
%     Problem           problem struct containing feasible or constraints
%     Threshold         classification threshold (default 0.5)
%     BinCount          equal-width reliability bins (default 10)
%     MaxCurvePoints    maximum displayed/returned points per ECDF/ROC curve
%                       (default 5000; scalar metrics remain exact)
%     IncludeSampleValues include score/truth/points in metrics (false)
%     SampleDescription provenance text for the validation population
%     OutputFile        optional export path
%     Resolution        raster export resolution (default 300 dpi)
%     Title             optional figure title

    arguments
        result (1,1) struct
        options.Iteration double = []
        options.Score double = []
        options.Truth = []
        options.Points double = []
        options.Problem (1,1) struct = struct()
        options.Threshold (1,1) double {mustBeReal, mustBeFinite} = 0.5
        options.BinCount (1,1) double {mustBeInteger, mustBePositive} = 10
        options.MaxCurvePoints (1,1) double ...
            {mustBeInteger, mustBePositive} = 5000
        options.IncludeSampleValues (1,1) logical = false
        options.SampleDescription (1,1) string = ...
            "Supplied or logged validation sample"
        options.OutputFile (1,1) string = ""
        options.Resolution (1,1) double {mustBePositive, mustBeFinite} = 300
        options.Title (1,1) string = ""
    end

    if options.Threshold < 0 || options.Threshold > 1
        error("cTSEMO:Diagnostics:InvalidThreshold", ...
            "Threshold must lie in [0,1].");
    end

    [score, truth, points, sourceInfo] = resolveValidationData( ...
        result, options);
    [score, truth, points, omittedCount] = canonicalValidationData( ...
        score, truth, points);
    if isempty(score)
        error("cTSEMO:Diagnostics:EmptyValidationData", ...
            "No finite paired p_i scores and truth labels were available.");
    end

    [fpr, tpr, rocThreshold, auc, rocReduced] = rocCurve( ...
        score, truth, options.MaxCurvePoints);
    calibration = reliabilityStatistics( ...
        score, truth, options.BinCount);
    confusion = confusionStatistics( ...
        score, truth, options.Threshold);
    brierScore = mean((score - double(truth)).^2);

    colors = diagnosticPalette();
    figureHandle = figure( ...
        "Visible", "off", ...
        "Color", "white", ...
        "Units", "pixels", ...
        "Position", [100, 100, 1180, 900]);
    layout = tiledlayout(figureHandle, 2, 2, ...
        "TileSpacing", "compact", "Padding", "compact");

    titleText = options.Title;
    if titleText == ""
        titleText = "Clipped feasibility-score validation";
    end
    title(layout, titleText, "Interpreter", "none", "FontWeight", "bold");

    ecdfAxes = nexttile(layout);
    drawConditionalEcdf( ...
        ecdfAxes, score, truth, colors, options.MaxCurvePoints);

    rocAxes = nexttile(layout);
    drawRoc(rocAxes, fpr, tpr, auc, colors);

    reliabilityAxes = nexttile(layout);
    drawReliability( ...
        reliabilityAxes, calibration, brierScore, colors);

    confusionAxes = nexttile(layout);
    drawConfusion(confusionAxes, confusion, options.Threshold, colors);

    metrics = struct();
    metrics.sampleCount = numel(score);
    metrics.feasibleCount = nnz(truth);
    metrics.infeasibleCount = nnz(~truth);
    metrics.omittedNonfiniteCount = omittedCount;
    metrics.brierScore = brierScore;
    metrics.auc = auc;
    metrics.rocFalsePositiveRate = fpr;
    metrics.rocTruePositiveRate = tpr;
    metrics.rocThreshold = rocThreshold;
    metrics.reliability = calibration;
    metrics.confusion = confusion;
    metrics.falseFeasibleRate = safeRatio( ...
        confusion.falsePositive, ...
        confusion.trueNegative + confusion.falsePositive);
    metrics.falseInfeasibleRate = safeRatio( ...
        confusion.falseNegative, ...
        confusion.truePositive + confusion.falseNegative);
    metrics.threshold = options.Threshold;
    metrics.rocCurveDownsampled = rocReduced;
    if options.IncludeSampleValues
        metrics.score = score;
        metrics.truth = truth;
        metrics.points = points;
    else
        metrics.score = zeros(0, 1);
        metrics.truth = false(0, 1);
        metrics.points = zeros(0, size(points, 2));
    end

    metadata = struct();
    metadata.figureType = "clipped feasibility-score validation";
    metadata.positiveClass = "feasible";
    metadata.sampleDescription = options.SampleDescription;
    metadata.validationSource = sourceInfo;
    metadata.caption = compose( ...
        "Validation of one clipped p_i field over %d labelled points. " + ...
        "The two ECDF curves are conditional distributions of that same " + ...
        "field, not separate feasible and infeasible PoF models. Feasible " + ...
        "is the positive class. Reliability bins are equal width; marker " + ...
        "area is proportional to bin count. Classification uses p_i >= %g.", ...
        numel(score), options.Threshold);
    metadata.calibrationCaveat = ...
        "p_i is an operational feasibility score rather than a Bernoulli " + ...
        "posterior. Brier and reliability values diagnose empirical " + ...
        "alignment; they do not by themselves establish calibration.";
    metadata.samplingCaveat = ...
        "All metrics are conditional on the supplied validation sampling " + ...
        "measure. Logged optimizer candidates are not a volume-weighted " + ...
        "domain sample; use an independent grid or space-filling probe for " + ...
        "domain-wide interpretation.";
    metadata.curvePointLimit = options.MaxCurvePoints;
    metadata.generatedAt = datetime("now", "TimeZone", "local");

    exportDiagnosticFigure( ...
        figureHandle, options.OutputFile, options.Resolution);
end

function [score, truth, points, info] = resolveValidationData(result, options)
    score = options.Score(:);
    truth = options.Truth;
    points = options.Points;
    info = struct( ...
        "mode", "explicit", ...
        "scorePath", "", ...
        "truthPath", "", ...
        "iteration", NaN, ...
        "fullRecordFile", "");

    if ~isempty(score)
        if isempty(truth)
            truth = evaluateTruthAtPoints(options.Problem, points);
        end
        if isempty(truth)
            error("cTSEMO:Diagnostics:MissingValidationTruth", ...
                "Supply Truth, or supply Points and a Problem truth handle.");
        end
        return
    end

    [record, ~, loadInfo] = loadIterationDiagnostic( ...
        result, options.Iteration);
    info.mode = loadInfo.mode;
    info.iteration = loadInfo.loggedIteration;
    info.fullRecordFile = loadInfo.fullRecordFile;

    [score, hasScore, scorePath] = diagnosticGet(record, [ ...
        "validation.pof", "validation.p_i", "validation.score", ...
        "candidates.pof", "candidateDiagnostics.pof", ...
        "grid.pof"], []);
    if ~hasScore
        error("cTSEMO:Diagnostics:MissingValidationScore", ...
            "No validation p_i field was stored. Supply Score and Truth, " + ...
            "or enable full iteration logging.");
    end
    score = score(:);
    info.scorePath = scorePath;

    [points, hasPoints] = diagnosticGet(record, [ ...
        "validation.X", "candidates.X", "candidateDiagnostics.X", ...
        "grid.X"], []);
    if ~hasPoints
        points = zeros(0, 0);
    end

    [truth, hasTruth, truthPath] = diagnosticGet(record, [ ...
        "validation.isFeasible", "validation.truth", ...
        "candidates.isFeasible", "candidateDiagnostics.isFeasible", ...
        "grid.isFeasible"], []);
    if hasTruth
        info.truthPath = truthPath;
    else
        truth = evaluateTruthAtPoints(options.Problem, points);
        info.truthPath = "supplied problem truth handle";
    end
    if isempty(truth)
        error("cTSEMO:Diagnostics:MissingValidationTruth", ...
            "Validation truth was not stored. Supply Problem with a " + ...
            "feasible or constraintMargins handle, or supply Score and Truth.");
    end
end

function truth = evaluateTruthAtPoints(problem, points)
    truth = [];
    if isempty(points) || isempty(fieldnames(problem))
        return
    end

    [feasibleFunction, found] = diagnosticGet(problem, ...
        ["feasible", "trueFeasibility"], []);
    if found && isa(feasibleFunction, "function_handle")
        truth = feasibleFunction(points);
        return
    end

    [constraintFunction, found] = diagnosticGet(problem, ...
        ["constraintMargins", "constraint", "g"], []);
    if found && isa(constraintFunction, "function_handle")
        margins = constraintFunction(points);
        truth = all(isfinite(margins) & margins <= 0, 2);
    end
end

function [score, truth, points, omitted] = canonicalValidationData( ...
        score, truth, points)
    if ~(islogical(truth) || isnumeric(truth))
        error("cTSEMO:Diagnostics:InvalidValidationTruth", ...
            "Truth must be logical or explicit numeric 0/1 labels.");
    end
    if isnumeric(truth) && ...
            (~all(isfinite(truth), "all") || ...
            ~all(truth == 0 | truth == 1, "all"))
        error("cTSEMO:Diagnostics:AmbiguousValidationTruth", ...
            "Numeric Truth must contain only 0 and 1, with 1 meaning feasible.");
    end

    truth = logical(truth(:));
    if numel(score) ~= numel(truth)
        error("cTSEMO:Diagnostics:ValidationSizeMismatch", ...
            "Score and Truth must contain the same number of elements.");
    end
    if ~isempty(points) && size(points, 1) ~= numel(score)
        error("cTSEMO:Diagnostics:ValidationPointMismatch", ...
            "Points must contain one row for every score.");
    end

    tolerance = 100 * eps;
    outside = score < -tolerance | score > 1 + tolerance;
    if any(outside & isfinite(score))
        error("cTSEMO:Diagnostics:UnclippedValidationScore", ...
            "Validation scores must be clipped to [0,1].");
    end

    finite = isfinite(score);
    omitted = nnz(~finite);
    score = min(1, max(0, double(score(finite))));
    truth = truth(finite);
    if ~isempty(points)
        points = points(finite, :);
    end
end

function [fpr, tpr, thresholds, auc, reduced] = ...
        rocCurve(score, truth, maximumPoints)
    positiveCount = nnz(truth);
    negativeCount = nnz(~truth);
    if positiveCount == 0 || negativeCount == 0
        fpr = [];
        tpr = [];
        thresholds = [];
        auc = NaN;
        reduced = false;
        return
    end

    [sortedScore, order] = sort(score, "descend");
    sortedTruth = truth(order);
    cumulativePositive = cumsum(double(sortedTruth));
    cumulativeNegative = cumsum(double(~sortedTruth));
    groupEnd = [find(diff(sortedScore) ~= 0); numel(sortedScore)];

    tpr = [0; cumulativePositive(groupEnd) ./ positiveCount; 1];
    fpr = [0; cumulativeNegative(groupEnd) ./ negativeCount; 1];
    thresholds = [Inf; sortedScore(groupEnd); -Inf];
    auc = trapz(fpr, tpr);
    [fpr, tpr, thresholds, reduced] = reduceCurve( ...
        fpr, tpr, thresholds, maximumPoints);
end

function [x, y, threshold, reduced] = reduceCurve( ...
        x, y, threshold, maximumPoints)
    reduced = numel(x) > maximumPoints;
    if ~reduced
        return
    end
    index = unique(round(linspace(1, numel(x), maximumPoints)));
    x = x(index);
    y = y(index);
    threshold = threshold(index);
end

function calibration = reliabilityStatistics(score, truth, binCount)
    edges = linspace(0, 1, binCount + 1);
    bin = discretize(score, edges);
    meanScore = NaN(binCount, 1);
    observedRate = NaN(binCount, 1);
    count = zeros(binCount, 1);

    for index = 1:binCount
        selected = bin == index;
        count(index) = nnz(selected);
        if count(index) > 0
            meanScore(index) = mean(score(selected));
            observedRate(index) = mean(truth(selected));
        end
    end

    occupied = count > 0;
    ece = sum(count(occupied) .* ...
        abs(meanScore(occupied) - observedRate(occupied))) ./ numel(score);
    calibration = table( ...
        (1:binCount).', edges(1:end-1).', edges(2:end).', ...
        meanScore, observedRate, count, ...
        'VariableNames', { ...
        'Bin', 'LowerEdge', 'UpperEdge', 'MeanScore', ...
        'ObservedFeasibleRate', 'Count'});
    calibration.Properties.UserData.expectedCalibrationError = ece;
end

function confusion = confusionStatistics(score, truth, threshold)
    predicted = score >= threshold;
    trueNegative = nnz(~truth & ~predicted);
    falsePositive = nnz(~truth & predicted);
    falseNegative = nnz(truth & ~predicted);
    truePositive = nnz(truth & predicted);

    sensitivity = safeRatio(truePositive, truePositive + falseNegative);
    specificity = safeRatio(trueNegative, trueNegative + falsePositive);
    balancedAccuracy = mean([sensitivity, specificity], "omitnan");
    confusion = struct( ...
        "matrix", [trueNegative, falsePositive; ...
        falseNegative, truePositive], ...
        "trueNegative", trueNegative, ...
        "falsePositive", falsePositive, ...
        "falseNegative", falseNegative, ...
        "truePositive", truePositive, ...
        "sensitivity", sensitivity, ...
        "specificity", specificity, ...
        "balancedAccuracy", balancedAccuracy);
end

function value = safeRatio(numerator, denominator)
    if denominator == 0
        value = NaN;
    else
        value = numerator / denominator;
    end
end

function drawConditionalEcdf( ...
        axesHandle, score, truth, colors, maximumPoints)
    hold(axesHandle, "on");
    drawEcdfGroup(axesHandle, score(~truth), colors.ink, "--", ...
        "True infeasible", maximumPoints);
    drawEcdfGroup(axesHandle, score(truth), colors.blue, "-", ...
        "True feasible", maximumPoints);
    hold(axesHandle, "off");

    xlim(axesHandle, [0, 1]);
    ylim(axesHandle, [0, 1]);
    xlabel(axesHandle, "Clipped feasibility score p_i");
    ylabel(axesHandle, "Empirical cumulative probability");
    title(axesHandle, "Conditional ECDFs of one p_i field");
    legend(axesHandle, "Location", "southeast", "Box", "off");
    grid(axesHandle, "on");
    axesHandle.GridAlpha = 0.15;
end

function drawEcdfGroup( ...
        axesHandle, values, color, lineStyle, label, maximumPoints)
    if isempty(values)
        plot(axesHandle, NaN, NaN, lineStyle, ...
            "Color", color, "LineWidth", 1.4, "DisplayName", ...
            label + " (no observations)");
        return
    end
    values = sort(values);
    index = unique(round(linspace( ...
        1, numel(values), min(maximumPoints, numel(values))))).';
    probability = index ./ numel(values);
    stairs(axesHandle, [0; values(index); 1], [0; probability; 1], ...
        lineStyle, "Color", color, "LineWidth", 1.4, ...
        "DisplayName", label);
end

function drawRoc(axesHandle, fpr, tpr, auc, colors)
    if isempty(fpr)
        plotUnavailableTile(axesHandle, ...
            "ROC: feasible as positive class", ...
            "ROC/AUC requires both true feasible and true infeasible points.");
        return
    end

    plot(axesHandle, [0, 1], [0, 1], ":", ...
        "Color", colors.midGray, "LineWidth", 1.0);
    hold(axesHandle, "on");
    plot(axesHandle, fpr, tpr, "-", ...
        "Color", colors.orange, "LineWidth", 1.6);
    hold(axesHandle, "off");

    axis(axesHandle, "square");
    xlim(axesHandle, [0, 1]);
    ylim(axesHandle, [0, 1]);
    xlabel(axesHandle, "False-feasible rate");
    ylabel(axesHandle, "True-feasible rate");
    title(axesHandle, compose("ROC: feasible positive (AUC = %.3f)", auc));
    legend(axesHandle, ["No-skill diagonal", "p_i ranking"], ...
        "Location", "southeast", "Box", "off");
    grid(axesHandle, "on");
    axesHandle.GridAlpha = 0.15;
end

function drawReliability(axesHandle, calibration, brier, colors)
    occupied = calibration.Count > 0;
    ece = calibration.Properties.UserData.expectedCalibrationError;
    plot(axesHandle, [0, 1], [0, 1], ":", ...
        "Color", colors.midGray, "LineWidth", 1.0);
    hold(axesHandle, "on");
    markerSize = 24 + 80 .* ...
        calibration.Count(occupied) ./ max(calibration.Count(occupied));
    scatter(axesHandle, calibration.MeanScore(occupied), ...
        calibration.ObservedFeasibleRate(occupied), markerSize, ...
        "o", "MarkerFaceColor", colors.blue, ...
        "MarkerEdgeColor", colors.ink, "LineWidth", 0.6);
    plot(axesHandle, calibration.MeanScore(occupied), ...
        calibration.ObservedFeasibleRate(occupied), "-", ...
        "Color", colors.blue, "LineWidth", 1.0);
    hold(axesHandle, "off");

    axis(axesHandle, "square");
    xlim(axesHandle, [0, 1]);
    ylim(axesHandle, [0, 1]);
    xlabel(axesHandle, "Mean p_i in occupied bin");
    ylabel(axesHandle, "Observed feasible fraction");
    title(axesHandle, "Reliability diagram");
    subtitle(axesHandle, compose( ...
        "Brier = %.4f; equal-width ECE = %.4f", brier, ece));
    grid(axesHandle, "on");
    axesHandle.GridAlpha = 0.15;
end

function drawConfusion(axesHandle, confusion, threshold, colors)
    imagesc(axesHandle, confusion.matrix);
    axis(axesHandle, "image");
    colormap(axesHandle, ...
        [linspace(1, colors.blue(1), 256).', ...
        linspace(1, colors.blue(2), 256).', ...
        linspace(1, colors.blue(3), 256).']);
    colorbar(axesHandle);
    xticks(axesHandle, 1:2);
    yticks(axesHandle, 1:2);
    xticklabels(axesHandle, ["Predicted infeasible", "Predicted feasible"]);
    yticklabels(axesHandle, ["True infeasible", "True feasible"]);
    title(axesHandle, compose( ...
        "Confusion at p_i >= %g", threshold));

    maximum = max(confusion.matrix, [], "all");
    for row = 1:2
        for column = 1:2
            value = confusion.matrix(row, column);
            if maximum > 0 && value > maximum / 2
                textColor = [1, 1, 1];
            else
                textColor = colors.ink;
            end
            text(axesHandle, column, row, string(value), ...
                "HorizontalAlignment", "center", ...
                "VerticalAlignment", "middle", ...
                "FontWeight", "bold", "Color", textColor);
        end
    end
    subtitle(axesHandle, compose( ...
        "Balanced accuracy = %.3f", confusion.balancedAccuracy));
end
