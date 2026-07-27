function data = extractResultData(result)
%EXTRACTRESULTDATA Return canonical observed designs, objectives, and labels.

    arguments
        result (1,1) struct
    end

    [X, hasX] = diagnosticGet(result, ["data.X", "X"], []);
    [Y, hasY] = diagnosticGet(result, ["data.Y", "Y"], []);
    [isFeasible, hasFeasible] = diagnosticGet(result, ...
        ["data.isFeasible", "data.feasible", "isFeasible"], []);
    [nInitial, hasInitial] = diagnosticGet(result, ...
        ["data.nInitial", "data.initialCount", "meta.nInitial"], []);

    if ~hasX
        X = zeros(0, 0);
    end
    if ~hasY
        Y = zeros(size(X, 1), 0);
    end
    if ~hasFeasible
        isFeasible = true(size(X, 1), 1);
    end

    validateattributes(X, {'numeric'}, {'2d', 'real'}, mfilename, "X");
    validateattributes(Y, {'numeric'}, {'2d', 'real'}, mfilename, "Y");
    if size(Y, 1) ~= size(X, 1)
        error("cTSEMO:Diagnostics:ResultRowMismatch", ...
            "The stored design and objective histories have different row counts.");
    end

    isFeasible = canonicalLogical(isFeasible, size(X, 1));
    if ~(hasInitial && isnumeric(nInitial) && isscalar(nInitial) && ...
            isfinite(nInitial) && nInitial >= 0 && fix(nInitial) == nInitial)
        [iterations, hasIterations] = diagnosticGet(result, "iterations", []);
        if hasIterations
            nInitial = max(0, size(X, 1) - numel(iterations));
        else
            nInitial = size(X, 1);
        end
    end

    data = struct( ...
        "X", double(X), ...
        "Y", double(Y), ...
        "isFeasible", isFeasible, ...
        "nInitial", double(nInitial), ...
        "hasStoredX", hasX, ...
        "hasStoredY", hasY, ...
        "hasStoredFeasibility", hasFeasible);
end

function labels = canonicalLogical(values, expectedRows)
    if isempty(values) && expectedRows == 0
        labels = false(0, 1);
        return
    end
    if islogical(values)
        labels = values(:);
    elseif isnumeric(values) && all(isfinite(values), "all") && ...
            all(values == 0 | values == 1, "all")
        labels = logical(values(:));
    else
        error("cTSEMO:Diagnostics:AmbiguousFeasibility", ...
            "Stored feasibility labels must be logical or explicit 0/1 values.");
    end
    if numel(labels) ~= expectedRows
        error("cTSEMO:Diagnostics:FeasibilityRowMismatch", ...
            "The stored feasibility history has the wrong number of rows.");
    end
end
