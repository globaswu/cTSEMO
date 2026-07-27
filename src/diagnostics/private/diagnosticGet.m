function [value, found, matchedPath] = diagnosticGet(source, paths, defaultValue)
%DIAGNOSTICGET Read the first available case-insensitive nested field.

    arguments
        source
        paths (1,:) string
        defaultValue = []
    end

    value = defaultValue;
    found = false;
    matchedPath = "";

    for path = paths
        [candidate, candidateFound] = readPath(source, path);
        if candidateFound
            value = candidate;
            found = true;
            matchedPath = path;
            return
        end
    end
end

function [value, found] = readPath(source, path)
    parts = split(path, ".");
    value = source;
    found = true;

    for index = 1:numel(parts)
        part = parts(index);
        if isstruct(value) && isscalar(value)
            names = string(fieldnames(value));
            match = find(strcmpi(names, part), 1);
            if isempty(match)
                found = false;
                value = [];
                return
            end
            value = value.(names(match));
        elseif istable(value) && height(value) == 1
            names = string(value.Properties.VariableNames);
            match = find(strcmpi(names, part), 1);
            if isempty(match)
                found = false;
                value = [];
                return
            end
            value = value.(names(match));
            if iscell(value) && isscalar(value)
                value = value{1};
            end
        else
            found = false;
            value = [];
            return
        end
    end
end
