function [lowerBound, upperBound] = resolveProblemBounds(result, problem)
%RESOLVEPROBLEMBOUNDS Find physical design bounds without deriving new ones.

    arguments
        result (1,1) struct
        problem (1,1) struct = struct()
    end

    [lowerBound, hasLower] = diagnosticGet(problem, ...
        ["lowerBound", "lb"], []);
    [upperBound, hasUpper] = diagnosticGet(problem, ...
        ["upperBound", "ub"], []);
    if ~(hasLower && hasUpper)
        [lowerBound, hasLower] = diagnosticGet(result, ...
            ["problem.lowerBound", "problem.lb", "lowerBound", "lb"], []);
        [upperBound, hasUpper] = diagnosticGet(result, ...
            ["problem.upperBound", "problem.ub", "upperBound", "ub"], []);
    end
    if ~(hasLower && hasUpper)
        error("cTSEMO:Diagnostics:MissingBounds", ...
            "Design bounds were not found in the result or supplied problem.");
    end

    lowerBound = reshape(double(lowerBound), 1, []);
    upperBound = reshape(double(upperBound), 1, []);
    if isempty(lowerBound) || numel(lowerBound) ~= numel(upperBound) || ...
            any(~isfinite(lowerBound)) || any(~isfinite(upperBound)) || ...
            any(lowerBound >= upperBound)
        error("cTSEMO:Diagnostics:InvalidBounds", ...
            "The stored lower and upper bounds are invalid.");
    end
end
