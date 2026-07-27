function [summary, records] = ...
        seal_dimension_study_sources(studyDirectory)
%SEAL_DIMENSION_STUDY_SOURCES Seal MATLAB study sources.
%   [SUMMARY, RECORDS] =
%   SEAL_DIMENSION_STUDY_SOURCES(STUDYDIRECTORY) inventories every MATLAB
%   source file below src and the dimension-study runner,
%   launcher, plotting, and validation scripts. It writes two deterministic
%   files into the supplied existing study directory:
%
%     source_manifest.csv
%     source_manifest_summary.json
%
%   Relative paths are sorted case-insensitively before serialization. Both
%   outputs are committed through temporary files in STUDYDIRECTORY. The
%   summary contains the SHA-256 digest of the exact CSV byte stream.

narginchk(1, 1);
validateattributes(studyDirectory, {'char', 'string'}, ...
    {'scalartext'}, mfilename, "studyDirectory");
studyDirectory = string(studyDirectory);
if ~isfolder(studyDirectory)
    error("cTSEMO:DimensionStudySeal:StudyDirectoryMissing", ...
        "The supplied study directory does not exist: %s", ...
        studyDirectory);
end

analysisDirectory = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(fileparts(analysisDirectory)));
releaseRoot = fullfile(repositoryRoot, "src");
if ~isfolder(releaseRoot)
    error("cTSEMO:DimensionStudySeal:ReleaseRootMissing", ...
        "The cTSEMO release directory does not exist: %s", releaseRoot);
end

studyScriptNames = [ ...
    "run_matched_dimension_pof_study.m", ...
    "launch_full_study.m", ...
    "plot_matched_dimension_pof_study.m", ...
    "validate_matched_dimension_pof_study.m"];
specifications = buildSpecifications( ...
    repositoryRoot, releaseRoot, analysisDirectory, studyScriptNames);
records = hashSpecifications(specifications);

manifestPath = fullfile(studyDirectory, "source_manifest.csv");
manifestHash = writeManifestAtomically(manifestPath, records);

categories = string({records.Category});
summary = struct( ...
    "SchemaVersion", 1, ...
    "Algorithm", "SHA-256", ...
    "ManifestFile", "source_manifest.csv", ...
    "ManifestSHA256", manifestHash, ...
    "SummaryFile", "source_manifest_summary.json", ...
    "FileCount", numel(records), ...
    "ReleaseMFileCount", nnz(categories == "release"), ...
    "StudyScriptCount", nnz(categories == "study"), ...
    "ReleaseRoot", "src", ...
    "StudyScripts", studyScriptNames, ...
    "Ordering", "Case-insensitive ascending repository-relative path", ...
    "AuthorityStatement", ...
        "ManifestSHA256 identifies the exact source_manifest.csv bytes.");
summaryPath = fullfile(studyDirectory, ...
    "source_manifest_summary.json");
writeJsonAtomically(summaryPath, summary);
end

function specifications = buildSpecifications( ...
        repositoryRoot, releaseRoot, analysisDirectory, studyScriptNames)
listing = dir(fullfile(releaseRoot, "**", "*.m"));
listing = listing(~[listing.isdir]);
if isempty(listing)
    error("cTSEMO:DimensionStudySeal:NoReleaseSources", ...
        "No MATLAB source files were found below %s.", releaseRoot);
end

specifications = repmat(emptySpecification(), ...
    numel(listing) + numel(studyScriptNames), 1);
recordIndex = 0;
for index = 1:numel(listing)
    recordIndex = recordIndex + 1;
    absolutePath = string(fullfile( ...
        listing(index).folder, listing(index).name));
    specifications(recordIndex) = makeSpecification( ...
        "release", absolutePath, repositoryRoot);
end

for scriptName = studyScriptNames
    absolutePath = fullfile(analysisDirectory, scriptName);
    if ~isfile(absolutePath)
        error("cTSEMO:DimensionStudySeal:StudyScriptMissing", ...
            "Required study script is missing: %s", absolutePath);
    end
    recordIndex = recordIndex + 1;
    specifications(recordIndex) = makeSpecification( ...
        "study", absolutePath, repositoryRoot);
end

relativePaths = string({specifications.RelativePath});
normalizedPaths = lower(relativePaths);
if numel(unique(normalizedPaths)) ~= numel(normalizedPaths)
    error("cTSEMO:DimensionStudySeal:DuplicatePath", ...
        "The source inventory contains duplicate relative paths.");
end
[~, order] = sort(normalizedPaths);
specifications = specifications(order);

expectedPublicApi = "src/cTSEMO.m";
if ~any(string({specifications.RelativePath}) == expectedPublicApi)
    error("cTSEMO:DimensionStudySeal:IncompleteReleaseInventory", ...
        "The recursive inventory omitted %s.", expectedPublicApi);
end
end

function specification = makeSpecification( ...
        category, absolutePath, repositoryRoot)
absolutePath = string(absolutePath);
repositoryRoot = string(repositoryRoot);
prefix = repositoryRoot + filesep;
if ~startsWith(lower(absolutePath), lower(prefix))
    error("cTSEMO:DimensionStudySeal:PathOutsideRepository", ...
        "A source path lies outside the repository root: %s", ...
        absolutePath);
end
relativePath = extractAfter(absolutePath, strlength(prefix));
relativePath = replace(relativePath, "\", "/");
specification = struct( ...
    "Category", string(category), ...
    "RelativePath", relativePath, ...
    "AbsolutePath", absolutePath);
end

function records = hashSpecifications(specifications)
records = repmat(emptyRecord(), numel(specifications), 1);
for index = 1:numel(specifications)
    specification = specifications(index);
    before = dir(specification.AbsolutePath);
    if isempty(before)
        error("cTSEMO:DimensionStudySeal:SourceMissing", ...
            "A source disappeared before hashing: %s", ...
            specification.RelativePath);
    end
    digest = sha256File(specification.AbsolutePath);
    after = dir(specification.AbsolutePath);
    if isempty(after) || after.bytes ~= before.bytes || ...
            after.datenum ~= before.datenum
        error("cTSEMO:DimensionStudySeal:SourceChanged", ...
            "A source changed while being hashed: %s", ...
            specification.RelativePath);
    end
    records(index) = struct( ...
        "Category", specification.Category, ...
        "RelativePath", specification.RelativePath, ...
        "Bytes", double(before.bytes), ...
        "SHA256", digest);
end
end

function hash = writeManifestAtomically(pathValue, records)
temporaryPath = string(tempname(fileparts(pathValue))) + ".csv";
cleanup = onCleanup(@() removeTemporaryFile(temporaryPath));
writeManifestCsv(temporaryPath, records);
hash = sha256File(temporaryPath);
commitTemporaryFile(temporaryPath, pathValue);
clear cleanup

committedHash = sha256File(pathValue);
if committedHash ~= hash
    error("cTSEMO:DimensionStudySeal:ManifestCommitMismatch", ...
        "The committed source manifest does not match its computed hash.");
end
end

function writeManifestCsv(pathValue, records)
fileId = fopen(pathValue, "wb");
if fileId < 0
    error("cTSEMO:DimensionStudySeal:ManifestOpenFailure", ...
        "Could not open a temporary source manifest for writing.");
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, "Category,RelativePath,Bytes,SHA256\n");
for index = 1:numel(records)
    fprintf(fileId, """%s"",""%s"",%.0f,""%s""\n", ...
        escapeCsv(records(index).Category), ...
        escapeCsv(records(index).RelativePath), ...
        records(index).Bytes, ...
        escapeCsv(records(index).SHA256));
end
clear cleanup
end

function writeJsonAtomically(pathValue, value)
temporaryPath = string(tempname(fileparts(pathValue))) + ".json";
cleanup = onCleanup(@() removeTemporaryFile(temporaryPath));
encoded = [jsonencode(value, "PrettyPrint", true), newline];
bytes = unicode2native(char(encoded), "UTF-8");
fileId = fopen(temporaryPath, "wb");
if fileId < 0
    error("cTSEMO:DimensionStudySeal:JsonOpenFailure", ...
        "Could not open a temporary summary JSON file for writing.");
end
fileCleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, bytes, "uint8");
clear fileCleanup
commitTemporaryFile(temporaryPath, pathValue);
clear cleanup
end

function commitTemporaryFile(temporaryPath, finalPath)
[success, message] = movefile(temporaryPath, finalPath, "f");
if ~success
    error("cTSEMO:DimensionStudySeal:CommitFailure", ...
        "Could not commit '%s': %s", finalPath, message);
end
end

function hash = sha256File(pathValue)
messageDigest = java.security.MessageDigest.getInstance("SHA-256");
fileId = fopen(pathValue, "rb");
if fileId < 0
    error("cTSEMO:DimensionStudySeal:SourceOpenFailure", ...
        "Could not open a file for hashing: %s", pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
while ~feof(fileId)
    bytes = fread(fileId, 1024 * 1024, "*uint8");
    if ~isempty(bytes)
        messageDigest.update(typecast(bytes, "int8"));
    end
end
digest = typecast(messageDigest.digest(), "uint8");
hash = lower(string(reshape(dec2hex(digest, 2).', 1, [])));
clear cleanup
end

function textValue = escapeCsv(value)
textValue = char(replace(string(value), """", """"""));
end

function removeTemporaryFile(pathValue)
if isfile(pathValue)
    delete(pathValue);
end
end

function specification = emptySpecification()
specification = struct( ...
    "Category", "", ...
    "RelativePath", "", ...
    "AbsolutePath", "");
end

function record = emptyRecord()
record = struct( ...
    "Category", "", ...
    "RelativePath", "", ...
    "Bytes", 0, ...
    "SHA256", "");
end
