function exportDiagnosticFigure(figureHandle, outputFile, resolution)
%EXPORTDIAGNOSTICFIGURE Export a diagnostic figure with exportgraphics.

    arguments
        figureHandle (1,1) matlab.ui.Figure
        outputFile (1,1) string = ""
        resolution (1,1) double {mustBePositive, mustBeFinite} = 300
    end

    if outputFile == ""
        return
    end

    outputDirectory = fileparts(outputFile);
    if outputDirectory ~= "" && ~isfolder(outputDirectory)
        error("cTSEMO:Diagnostics:MissingOutputDirectory", ...
            "The output directory does not exist: %s", outputDirectory);
    end

    [~, ~, extension] = fileparts(outputFile);
    vectorExtensions = [".pdf", ".eps", ".svg"];
    if any(strcmpi(extension, vectorExtensions))
        exportgraphics(figureHandle, outputFile, "ContentType", "vector");
    else
        exportgraphics(figureHandle, outputFile, "Resolution", resolution);
    end
end
