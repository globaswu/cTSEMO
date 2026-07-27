function raster = computeSortedPofRaster4D(result, problem, options)
%COMPUTESORTEDPOFRASTER4D Compute a chunked four-dimensional rank raster.
%   RASTER = COMPUTESORTEDPOFRASTER4D(RESULT,PROBLEM) evaluates the final
%   clipped feasibility score on a tensor grid, sorts points by decreasing
%   p_i, and places them on a square plane in increasing row-plus-column
%   order. The maximum is placed at the upper-left corner and the minimum
%   at the lower-right corner. The default 50 points per dimension produce
%   50^4 = 6,250,000 evaluations and a 2500-by-2500 raster.
%
%   Truth labels are stored separately and are not read by the sorting or
%   tie-breaking logic. Exact score ties are ordered by ascending tensor
%   linear index. Neither truth labels nor errors influence ordering.
%
%   Name-value options:
%     PointsPerDimension  tensor resolution (default 50)
%     ChunkSize           maximum points evaluated per chunk (default 100000)
%     GridPlacement       "cellCenters" (default) or "endpoints"
%     Iteration           PoF model iteration (default last)
%     Model               explicit fitted clipped-PoF model
%     Predictor           function handle p_i = Predictor(Xphysical)
%     UseFinalData        reconstruct from all final binary data when no
%                         explicit Model/Predictor is supplied (default true)
%     ComputeTruth        evaluate supplied problem truth (default true)
%     Threshold           false-feasible classification threshold (0.5)
%     OutputFile          optional MAT-file path; saved with -v7.3
%     ProgressFunction    optional handle accepting (fraction,stage)

    arguments
        result (1,1) struct
        problem (1,1) struct
        options.PointsPerDimension (1,1) double ...
            {mustBeInteger, mustBePositive} = 50
        options.ChunkSize (1,1) double ...
            {mustBeInteger, mustBePositive} = 100000
        options.GridPlacement (1,1) string = "cellCenters"
        options.Iteration double = []
        options.Model = []
        options.Predictor = []
        options.UseFinalData (1,1) logical = true
        options.ComputeTruth (1,1) logical = true
        options.Threshold (1,1) double {mustBeReal, mustBeFinite} = 0.5
        options.OutputFile (1,1) string = ""
        options.ProgressFunction = []
    end

    if options.PointsPerDimension < 2
        error("cTSEMO:Diagnostics:RasterResolution", ...
            "PointsPerDimension must be at least two.");
    end
    mustBeMember(options.GridPlacement, ["cellCenters", "endpoints"]);
    if options.Threshold < 0 || options.Threshold > 1
        error("cTSEMO:Diagnostics:InvalidThreshold", ...
            "Threshold must lie in [0,1].");
    end
    validateProgressFunction(options.ProgressFunction);

    [lowerBound, upperBound] = resolveProblemBounds(result, problem);
    if numel(lowerBound) ~= 4
        error("cTSEMO:Diagnostics:RasterRequires4D", ...
            "computeSortedPofRaster4D requires exactly four input variables.");
    end

    pointsPerDimension = double(options.PointsPerDimension);
    totalPoints = pointsPerDimension ^ 4;
    if totalPoints > double(intmax("uint32"))
        error("cTSEMO:Diagnostics:RasterTooLarge", ...
            "The tensor grid exceeds the uint32 trace-index capacity.");
    end
    sideLength = pointsPerDimension ^ 2;
    [predictor, predictorSource] = resolvePredictor( ...
        result, lowerBound, upperBound, options);
    truthFunction = resolveTruthFunction(problem, options.ComputeTruth);

    score = zeros(totalPoints, 1);
    if options.ComputeTruth
        truth = false(totalPoints, 1);
    else
        truth = false(0, 1);
    end

    evaluationTimer = tic;
    chunkStart = 1:double(options.ChunkSize):totalPoints;
    for startIndex = chunkStart
        stopIndex = min(totalPoints, startIndex + options.ChunkSize - 1);
        tensorIndex = (startIndex:stopIndex).';
        X = tensorPoints( ...
            tensorIndex, pointsPerDimension, lowerBound, upperBound, ...
            options.GridPlacement);
        chunkScore = predictor(X);
        validateChunkScore(chunkScore, numel(tensorIndex));
        score(tensorIndex) = min(1, max(0, double(chunkScore(:))));

        if options.ComputeTruth
            chunkTruth = truthFunction(X);
            truth(tensorIndex) = canonicalTruth( ...
                chunkTruth, numel(tensorIndex));
        end
        reportProgress(options.ProgressFunction, ...
            stopIndex / totalPoints, "evaluate");
    end
    evaluationSeconds = toc(evaluationTimer);

    sortingTimer = tic;
    [sortedScore, pointOrder] = sort(score, "descend");
    pointOrder = makeTieOrderExplicit(sortedScore, pointOrder);
    sortingSeconds = toc(sortingTimer);

    layoutTimer = tic;
    scoreRaster = zeros(sideLength, sideLength);
    pointIndexRaster = zeros(sideLength, sideLength, "uint32");
    if options.ComputeTruth
        truthRaster = false(sideLength, sideLength);
    else
        truthRaster = false(0, 0);
    end

    cursor = 1;
    for diagonal = 2:(2 * sideLength)
        row = max(1, diagonal - sideLength):min(sideLength, diagonal - 1);
        column = diagonal - row;
        position = sub2ind([sideLength, sideLength], row, column);
        count = numel(position);
        rank = cursor:(cursor + count - 1);
        scoreRaster(position) = sortedScore(rank);
        pointIndexRaster(position) = uint32(pointOrder(rank));
        if options.ComputeTruth
            truthRaster(position) = truth(pointOrder(rank));
        end
        cursor = cursor + count;
    end
    if cursor ~= totalPoints + 1
        error("cTSEMO:Diagnostics:RasterLayoutFailure", ...
            "The diagonal rank layout did not consume every tensor point.");
    end
    layoutSeconds = toc(layoutTimer);

    if options.ComputeTruth
        predictedFeasible = scoreRaster >= options.Threshold;
        errorRaster = zeros(sideLength, sideLength, "int8");
        errorRaster(predictedFeasible & ~truthRaster) = int8(1);
        errorRaster(~predictedFeasible & truthRaster) = int8(-1);
    else
        errorRaster = zeros(0, 0, "int8");
    end

    axesValues = cell(1, 4);
    for dimension = 1:4
        axesValues{dimension} = oneDimensionalGrid( ...
            pointsPerDimension, lowerBound(dimension), ...
            upperBound(dimension), options.GridPlacement);
    end
    scoreSummary = struct( ...
        "minimum", min(score), ...
        "maximum", max(score), ...
        "mean", mean(score), ...
        "median", median(score), ...
        "fractionAtZero", mean(score == 0), ...
        "fractionAtOne", mean(score == 1));
    if options.ComputeTruth
        errorSummary = struct( ...
            "truthFeasibleFraction", mean(truth), ...
            "predictedFeasibleFraction", mean(score >= options.Threshold), ...
            "falseFeasibleCount", nnz(errorRaster == 1), ...
            "falseInfeasibleCount", nnz(errorRaster == -1), ...
            "correctCount", nnz(errorRaster == 0));
    else
        errorSummary = struct();
    end

    raster = struct();
    raster.kind = "ctsemoSortedPofRaster4D-v1";
    raster.score = scoreRaster;
    raster.truth = truthRaster;
    raster.error = errorRaster;
    raster.tensorLinearIndex = pointIndexRaster;
    raster.threshold = options.Threshold;
    raster.pointsPerDimension = pointsPerDimension;
    raster.totalPoints = totalPoints;
    raster.sideLength = sideLength;
    raster.lowerBound = lowerBound;
    raster.upperBound = upperBound;
    raster.axesValues = axesValues;
    raster.gridPlacement = options.GridPlacement;
    raster.predictorSource = predictorSource;
    raster.truthComputed = options.ComputeTruth;
    raster.ordering = ...
        "Descending clipped p_i; exact ties use ascending four-dimensional " + ...
        "tensor linear index. Ranked points are assigned to increasing " + ...
        "row-plus-column diagonals, then increasing row. Truth is not used.";
    raster.scoreSummary = scoreSummary;
    raster.errorSummary = errorSummary;
    raster.timing = struct( ...
        "evaluationSeconds", evaluationSeconds, ...
        "sortingSeconds", sortingSeconds, ...
        "layoutSeconds", layoutSeconds);
    raster.generatedAt = datetime("now", "TimeZone", "local");

    reportProgress(options.ProgressFunction, 1, "complete");
    saveRaster(raster, options.OutputFile);
end

function [predictor, source] = resolvePredictor(result, lb, ub, options)
    if ~isempty(options.Predictor)
        if ~isa(options.Predictor, "function_handle")
            error("cTSEMO:Diagnostics:InvalidPredictor", ...
                "Predictor must be a function handle.");
        end
        predictor = options.Predictor;
        source = "explicit physical-coordinate predictor";
        return
    end

    model = options.Model;
    modelSource = "explicit model";
    if isempty(model)
        found = false;
        if options.UseFinalData
            [model, found] = reconstructFinalModel(result, lb, ub);
            modelSource = ...
                "reconstructed from final stored binary data and run options";
        end
        if ~found
            [model, found] = diagnosticGet(result, ...
                ["models.pofModel", "pofModel"], []);
            found = found && isUsableModel(model);
            modelSource = "stored result model";
        end
        if ~found
            [iterations, hasIterations] = diagnosticGet( ...
                result, "iterations", []);
            if hasIterations && ~isempty(iterations)
                [record, ~, loadInfo] = loadIterationDiagnostic( ...
                    result, options.Iteration);
                [model, found] = diagnosticGet(record, ...
                    ["pofModel", "models.pofModel", "full.pofModel"], []);
                found = found && isUsableModel(model);
                modelSource = "iteration " + ...
                    string(loadInfo.loggedIteration) + ...
                    " full-record model";
            end
        end
        if ~found && ~options.UseFinalData
            [model, found] = reconstructFinalModel(result, lb, ub);
            modelSource = ...
                "reconstructed from final stored binary data and run options";
        end
        if ~found
            error("cTSEMO:Diagnostics:MissingPofModel", ...
                "No fitted p_i model or reconstructable binary data was found. " + ...
                "Supply Model or Predictor, or retain the full iteration record.");
        end
    end
    if ~(isstruct(model) && isscalar(model))
        error("cTSEMO:Diagnostics:InvalidPofModel", ...
            "Model must be a scalar struct returned by the cTSEMO PoF fit.");
    end

    predictor = @(X) modelPrediction(model, X, lb, ub);
    source = modelSource;
end

function usable = isUsableModel(model)
    usable = isstruct(model) && isscalar(model) && ...
        ~isempty(fieldnames(model)) && isfield(model, "construction");
end

function [model, found] = reconstructFinalModel(result, lb, ub)
    model = [];
    found = false;
    data = extractResultData(result);
    if isempty(data.X) || size(data.X, 2) ~= numel(lb) || ...
            ~data.hasStoredFeasibility
        return
    end
    XUnit = (data.X - lb) ./ (ub - lb);
    if all(data.isFeasible)
        [runOptions, hasOptions] = diagnosticGet( ...
            result, "options", struct());
        rawValue = 1;
        if hasOptions
            [rawValue, ~] = diagnosticGet( ...
                runOptions, "pof.rawFeasible", 1);
        end
        model = struct( ...
            "construction", "constant_all_feasible", ...
            "dimension", size(XUnit, 2), ...
            "rawValue", double(rawValue), ...
            "clippedValue", 1);
    else
        [runOptions, hasOptions] = diagnosticGet( ...
            result, "options", struct());
        if ~hasOptions
            runOptions = struct();
        end
        model = ctsemo.fitClippedBinaryPof( ...
            XUnit, data.isFeasible, runOptions);
    end
    found = true;
end

function score = modelPrediction(model, X, lb, ub)
    XUnit = (X - lb) ./ (ub - lb);
    [construction, found] = diagnosticGet(model, "construction", "");
    if found && string(construction) == "constant_all_feasible"
        score = ones(size(XUnit, 1), 1);
    else
        score = ctsemo.predictClippedBinaryPof(model, XUnit);
    end
end

function truthFunction = resolveTruthFunction(problem, computeTruth)
    if ~computeTruth
        truthFunction = [];
        return
    end

    [feasibleFunction, found] = diagnosticGet(problem, ...
        ["feasible", "trueFeasibility"], []);
    if found && isa(feasibleFunction, "function_handle")
        truthFunction = feasibleFunction;
        return
    end

    [constraintFunction, found] = diagnosticGet(problem, ...
        ["constraintMargins", "constraint", "g"], []);
    if found && isa(constraintFunction, "function_handle")
        truthFunction = @(X) truthFromMargins(constraintFunction, X);
        return
    end

    error("cTSEMO:Diagnostics:MissingTruthFunction", ...
        "ComputeTruth is true, but the supplied problem contains no " + ...
        "feasible or constraintMargins function handle.");
end

function truth = truthFromMargins(constraintFunction, X)
    margins = constraintFunction(X);
    truth = all(isfinite(margins) & margins <= 0, 2);
end

function X = tensorPoints( ...
        index, pointsPerDimension, lb, ub, gridPlacement)
    [i1, i2, i3, i4] = ind2sub( ...
        repmat(pointsPerDimension, 1, 4), index);
    gridIndex = [i1, i2, i3, i4];
    if gridPlacement == "cellCenters"
        normalized = (double(gridIndex) - 0.5) ./ pointsPerDimension;
    else
        normalized = (double(gridIndex) - 1) ./ ...
            (pointsPerDimension - 1);
    end
    X = lb + normalized .* (ub - lb);
end

function values = oneDimensionalGrid( ...
        pointsPerDimension, lowerBound, upperBound, gridPlacement)
    if gridPlacement == "cellCenters"
        normalized = ((1:pointsPerDimension) - 0.5) ./ ...
            pointsPerDimension;
        values = lowerBound + normalized .* (upperBound - lowerBound);
    else
        values = linspace(lowerBound, upperBound, pointsPerDimension);
    end
end

function validateChunkScore(score, expectedCount)
    if ~isnumeric(score) || numel(score) ~= expectedCount || ...
            ~isreal(score) || any(~isfinite(score), "all")
        error("cTSEMO:Diagnostics:InvalidPredictedScore", ...
            "The p_i predictor must return one finite real value per point.");
    end
    tolerance = 100 * eps;
    if any(score < -tolerance | score > 1 + tolerance, "all")
        error("cTSEMO:Diagnostics:UnclippedPredictedScore", ...
            "The supplied predictor returned a value outside [0,1].");
    end
end

function truth = canonicalTruth(values, expectedCount)
    if islogical(values)
        truth = values(:);
    elseif isnumeric(values) && all(isfinite(values), "all") && ...
            all(values == 0 | values == 1, "all")
        truth = logical(values(:));
    else
        error("cTSEMO:Diagnostics:InvalidTruth", ...
            "The problem truth handle must return logical or explicit 0/1 values.");
    end
    if numel(truth) ~= expectedCount
        error("cTSEMO:Diagnostics:TruthSizeMismatch", ...
            "The problem truth handle returned the wrong number of labels.");
    end
end

function pointOrder = makeTieOrderExplicit(sortedScore, pointOrder)
    if numel(sortedScore) < 2
        return
    end
    groupStart = [1; find(diff(sortedScore) ~= 0) + 1];
    groupEnd = [groupStart(2:end) - 1; numel(sortedScore)];
    tiedGroup = find(groupEnd > groupStart);
    for index = reshape(tiedGroup, 1, [])
        range = groupStart(index):groupEnd(index);
        pointOrder(range) = sort(pointOrder(range), "ascend");
    end
end

function validateProgressFunction(progressFunction)
    if ~(isempty(progressFunction) || isa(progressFunction, "function_handle"))
        error("cTSEMO:Diagnostics:InvalidProgressFunction", ...
            "ProgressFunction must be empty or a function handle.");
    end
end

function reportProgress(progressFunction, fraction, stage)
    if ~isempty(progressFunction)
        progressFunction(fraction, stage);
    end
end

function saveRaster(raster, outputFile)
    if outputFile == ""
        return
    end
    outputDirectory = fileparts(outputFile);
    if outputDirectory ~= "" && ~isfolder(outputDirectory)
        error("cTSEMO:Diagnostics:MissingOutputDirectory", ...
            "The output directory does not exist: %s", outputDirectory);
    end
    save(outputFile, "raster", "-v7.3");
end
