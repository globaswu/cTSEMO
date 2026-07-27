function [figureHandle, metadata] = plotSortedPofRaster4D(raster, options)
%PLOTSORTEDPOFRASTER4D Plot score, truth, and error on one rank plane.
%   [FIGUREHANDLE,METADATA] = PLOTSORTEDPOFRASTER4D(RASTER) consumes the
%   output of computeSortedPofRaster4D. It does not re-sort points.
%
%   Error codes are:
%      -1  false infeasible (p_i below threshold, truth feasible)
%       0  correct threshold classification
%      +1  false feasible (p_i at/above threshold, truth infeasible)
%
%   Name-value options:
%     OutputFile  optional export path
%     Resolution  raster export resolution (default 300 dpi)
%     Title       optional figure title

    arguments
        raster (1,1) struct
        options.OutputFile (1,1) string = ""
        options.Resolution (1,1) double {mustBePositive, mustBeFinite} = 300
        options.Title (1,1) string = ""
    end

    validateRaster(raster);
    colors = diagnosticPalette();
    hasTruth = logical(raster.truthComputed) && ~isempty(raster.truth);
    columnCount = 1 + 2 * double(hasTruth);

    figureHandle = figure( ...
        "Visible", "off", ...
        "Color", "white", ...
        "Units", "pixels", ...
        "Position", [100, 100, 620 * columnCount, 640]);
    layout = tiledlayout(figureHandle, 1, columnCount, ...
        "TileSpacing", "compact", "Padding", "compact");

    titleText = options.Title;
    if titleText == ""
        titleText = compose( ...
            "Four-dimensional clipped-PoF rank raster (%d^4 points)", ...
            raster.pointsPerDimension);
    end
    title(layout, titleText, "Interpreter", "none", "FontWeight", "bold");

    scoreAxes = nexttile(layout);
    imagesc(scoreAxes, [0, 1], [0, 1], raster.score);
    set(scoreAxes, "YDir", "reverse");
    axis(scoreAxes, "image");
    colormap(scoreAxes, parula(256));
    clim(scoreAxes, [0, 1]);
    scoreBar = colorbar(scoreAxes);
    scoreBar.Label.String = "p_i";
    title(scoreAxes, "Sorted clipped feasibility score p_i");
    xlabel(scoreAxes, "Normalized rank-plane x");
    ylabel(scoreAxes, "Normalized rank-plane y");

    if hasTruth
        truthAxes = nexttile(layout);
        imagesc(truthAxes, [0, 1], [0, 1], double(raster.truth));
        set(truthAxes, "YDir", "reverse");
        axis(truthAxes, "image");
        colormap(truthAxes, [colors.ink; colors.gold]);
        clim(truthAxes, [-0.5, 1.5]);
        truthBar = colorbar(truthAxes);
        truthBar.Ticks = [0, 1];
        truthBar.TickLabels = ["Infeasible", "Feasible"];
        title(truthAxes, "True binary feasibility at identical ranks");
        xlabel(truthAxes, "Normalized rank-plane x");
        ylabel(truthAxes, "Normalized rank-plane y");

        errorAxes = nexttile(layout);
        imagesc(errorAxes, [0, 1], [0, 1], double(raster.error));
        set(errorAxes, "YDir", "reverse");
        axis(errorAxes, "image");
        colormap(errorAxes, [ ...
            colors.blue; colors.nearWhite; colors.orange]);
        clim(errorAxes, [-1.5, 1.5]);
        errorBar = colorbar(errorAxes);
        errorBar.Ticks = [-1, 0, 1];
        errorBar.TickLabels = [ ...
            "False infeasible", "Correct", "False feasible"];
        title(errorAxes, compose( ...
            "Threshold errors at p_i >= %g", raster.threshold));
        xlabel(errorAxes, "Normalized rank-plane x");
        ylabel(errorAxes, "Normalized rank-plane y");
    end

    metadata = struct();
    metadata.figureType = "four-dimensional rank-raster diagnostic";
    metadata.totalPoints = raster.totalPoints;
    metadata.pointsPerDimension = raster.pointsPerDimension;
    metadata.gridPlacement = raster.gridPlacement;
    metadata.threshold = raster.threshold;
    metadata.ordering = raster.ordering;
    metadata.caption = compose( ...
        "The clipped p_i field over %d four-dimensional %s tensor points, " + ...
        "sorted without truth labels and placed on a diagonal rank plane. " + ...
        "Truth and threshold errors use the identical point positions. " + ...
        "The plane is a rank-layout diagnostic, not a continuous geometric " + ...
        "projection of the four-dimensional domain.", ...
        raster.totalPoints, raster.gridPlacement);
    metadata.source = raster.predictorSource;
    metadata.generatedAt = datetime("now", "TimeZone", "local");

    exportDiagnosticFigure( ...
        figureHandle, options.OutputFile, options.Resolution);
end

function validateRaster(raster)
    required = [ ...
        "kind", "score", "truth", "error", "threshold", ...
        "pointsPerDimension", "totalPoints", "truthComputed", ...
        "ordering", "predictorSource", "gridPlacement"];
    if ~all(isfield(raster, required)) || ...
            string(raster.kind) ~= "ctsemoSortedPofRaster4D-v1"
        error("cTSEMO:Diagnostics:InvalidRaster", ...
            "raster must be returned by computeSortedPofRaster4D.");
    end
    validateattributes(raster.score, {'numeric'}, ...
        {'2d', 'real', 'finite', 'nonempty'}, mfilename, "raster.score");
    if size(raster.score, 1) ~= size(raster.score, 2)
        error("cTSEMO:Diagnostics:NonSquareRaster", ...
            "The sorted score raster must be square.");
    end
    if raster.truthComputed && ...
            (~isequal(size(raster.truth), size(raster.score)) || ...
            ~isequal(size(raster.error), size(raster.score)))
        error("cTSEMO:Diagnostics:RasterSizeMismatch", ...
            "Score, truth, and error rasters must have identical sizes.");
    end
end
