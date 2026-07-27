function update_artifact_manifest
%UPDATE_ARTIFACT_MANIFEST Rebuild the public manuscript artifact registry.
%   The registry records repository-relative paths only. Run this function
%   after adding or retiring manuscript evidence files.

artifactDirectory = fileparts(mfilename("fullpath"));
manuscriptDirectory = fileparts(artifactDirectory);
introductionDirectory = fullfile( ...
    manuscriptDirectory, "introduction_pof_comparison");
manifestPath = fullfile(artifactDirectory, "artifact_manifest.csv");

files = [
    dir(fullfile(artifactDirectory, "**", "*"))
    dir(fullfile(introductionDirectory, "**", "*"))];
files = files(~[files.isdir]);

absolutePaths = string(fullfile({files.folder}, {files.name}))';
relativePaths = erase(absolutePaths, ...
    string(manuscriptDirectory) + filesep);
relativePaths = replace(relativePaths, "\", "/");

keepFile = relativePaths ~= "artifacts/artifact_manifest.csv";
files = files(keepFile);
relativePaths = relativePaths(keepFile);

category = strings(size(relativePaths));
intendedRole = strings(size(relativePaths));
for fileIndex = 1:numel(relativePaths)
    pathParts = split(relativePaths(fileIndex), "/");
    if pathParts(1) == "introduction_pof_comparison"
        category(fileIndex) = "introduction_pof_comparison";
    elseif numel(pathParts) >= 3 && pathParts(1) == "artifacts"
        category(fileIndex) = pathParts(2);
    elseif isscalar(pathParts)
        category(fileIndex) = "index";
    else
        category(fileIndex) = "index";
    end
    intendedRole(fileIndex) = roleForCategory(category(fileIndex));
end

retentionStatus = repmat("retain during manuscript drafting", ...
    size(relativePaths));
fileSizeBytes = [files.bytes]';

artifactManifest = table( ...
    relativePaths, category, fileSizeBytes, intendedRole, retentionStatus, ...
    VariableNames=[ ...
        "RelativePath", "Category", "Bytes", ...
        "IntendedRole", "RetentionStatus"]);
artifactManifest = sortrows(artifactManifest, "RelativePath");
writetable(artifactManifest, manifestPath);

fprintf("Artifact manifest updated: %d files\n", ...
    height(artifactManifest));
fprintf("  %s\n", manifestPath);
end

function intendedRole = roleForCategory(category)
switch category
    case "introduction_pof_comparison"
        intendedRole = ...
            "executable Introduction PoF reproduction data and figures";
    case "release_campaign"
        intendedRole = ...
            "sealed campaign summaries manifests and final run records";
    case "diagnostics"
        intendedRole = ...
            "compact source data for manuscript figures and diagnostics";
    case "dimension_study"
        intendedRole = ...
            "fixed-budget dimensional-study evidence and validation";
    case "sensitivity"
        intendedRole = ...
            "matched computational-profile sensitivity evidence";
    case "tests"
        intendedRole = ...
            "human-readable and machine-readable release test evidence";
    case "competitors"
        intendedRole = ...
            "source index for the unmatched competitor pilot";
    otherwise
        intendedRole = ...
            "artifact index documentation or maintenance code";
end
end
