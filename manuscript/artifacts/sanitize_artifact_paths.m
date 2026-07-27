function sanitize_artifact_paths
%SANITIZE_ARTIFACT_PATHS Remove workstation-specific roots from text data.
%   Numerical values and relative path suffixes are left unchanged. The
%   replacements make copied public artifacts independent of one workstation.

artifactDirectory = fileparts(mfilename("fullpath"));
manuscriptDirectory = fileparts(artifactDirectory);
repositoryDirectory = fileparts(manuscriptDirectory);
workspaceDirectory = fileparts(repositoryDirectory);
desktopDirectory = fileparts(workspaceDirectory);

privateRoots = [
    string(workspaceDirectory)
    string(fullfile(desktopDirectory, "TSEMO-Constrain"))
    string(fullfile(desktopDirectory, "THESIS-Codex"))];
publicRoots = [
    "${PROJECT_ROOT}"
    "${LEGACY_TSEMO_ROOT}"
    "${MANUSCRIPT_ROOT}"];

textExtensions = [".csv", ".json", ".md", ".xml", ".txt"];
files = dir(fullfile(artifactDirectory, "**", "*"));
files = files(~[files.isdir]);

changedFileCount = 0;
for fileIndex = 1:numel(files)
    [~, ~, extension] = fileparts(files(fileIndex).name);
    if ~ismember(lower(string(extension)), textExtensions)
        continue
    end

    filePath = fullfile(files(fileIndex).folder, files(fileIndex).name);
    originalText = string(fileread(filePath));
    publicText = originalText;
    for rootIndex = 1:numel(privateRoots)
        privateRoot = privateRoots(rootIndex);
        publicRoot = publicRoots(rootIndex);
        publicText = replace(publicText, ...
            privateRoot + filesep, publicRoot + "/");
        publicText = replace(publicText, ...
            replace(privateRoot + filesep, "\", "\\"), ...
            publicRoot + "/");
        publicText = replace(publicText, ...
            replace(privateRoot, "\", "/") + "/", ...
            publicRoot + "/");
    end

    if publicText ~= originalText
        writeUtf8Text(filePath, publicText);
        changedFileCount = changedFileCount + 1;
    end
end

fprintf("Sanitized workstation paths in %d artifact files.\n", ...
    changedFileCount);
end

function writeUtf8Text(filePath, text)
fileIdentifier = fopen(filePath, "w", "n", "UTF-8");
assert(fileIdentifier ~= -1, ...
    "Unable to open artifact text file for writing: %s", filePath);
closeFile = onCleanup(@() fclose(fileIdentifier));
fprintf(fileIdentifier, "%s", text);
clear closeFile
end
