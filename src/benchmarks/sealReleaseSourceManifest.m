function [sourceSeal, records] = ...
        sealReleaseSourceManifest(releaseRoot, campaignDirectory)
%SEALRELEASESOURCEMANIFEST Seal shipped sources with SHA-256 hashes.
%   [SEAL, RECORDS] = SEALRELEASESOURCEMANIFEST(RELEASEROOT, OUTDIR)
%   inventories the public API, +ctsemo core, benchmark/test/diagnostic and
%   example code, root documentation, vendored source, and any test
%   artifacts currently present. Generated benchmark, diagnostic, and
%   solver-output directories are deliberately excluded.
%
%   The deterministic authority file is:
%     release_source_manifest.csv
%
%   Its SHA-256 digest is stored in:
%     release_source_manifest.sha256
%
%   MAT and JSON companions contain the same records plus descriptive
%   metadata. This is a content-addressed release seal; it does not claim a
%   Git commit for the surrounding workspace.

narginchk(2, 2);
validateattributes(releaseRoot, {'char', 'string'}, ...
    {'scalartext'}, mfilename, 'releaseRoot');
validateattributes(campaignDirectory, {'char', 'string'}, ...
    {'scalartext'}, mfilename, 'campaignDirectory');
releaseRoot = char(releaseRoot);
campaignDirectory = char(campaignDirectory);
if ~isfolder(releaseRoot)
    error('cTSEMO:SourceSeal:ReleaseRootMissing', ...
        'Release root does not exist: %s', releaseRoot);
end
if ~isfolder(campaignDirectory)
    error('cTSEMO:SourceSeal:OutputDirectoryMissing', ...
        'Campaign directory does not exist: %s', campaignDirectory);
end

manifestPath = fullfile(campaignDirectory, ...
    'release_source_manifest.csv');
hashPath = fullfile(campaignDirectory, ...
    'release_source_manifest.sha256');
matPath = fullfile(campaignDirectory, ...
    'release_source_manifest.mat');
jsonPath = fullfile(campaignDirectory, ...
    'release_source_manifest.json');
targets = {manifestPath, hashPath, matPath, jsonPath};
if any(cellfun(@isfile, targets))
    error('cTSEMO:SourceSeal:ImmutableSealExists', ...
        'Refusing to overwrite an existing release source seal.');
end

specifications = sourceSpecifications(releaseRoot);
records = repmat(emptyRecord(), numel(specifications), 1);
for index = 1:numel(specifications)
    specification = specifications(index);
    before = dir(specification.AbsolutePath);
    records(index).Category = specification.Category;
    records(index).RelativePath = specification.RelativePath;
    records(index).Bytes = before.bytes;
    records(index).SHA256 = sha256File(specification.AbsolutePath);
    after = dir(specification.AbsolutePath);
    if isempty(after) || after.bytes ~= before.bytes || ...
            after.datenum ~= before.datenum
        error('cTSEMO:SourceSeal:SourceChangedDuringHash', ...
            'Source changed while it was being hashed: %s', ...
            specification.RelativePath);
    end
end

[~, order] = sort(lower(string({records.RelativePath})));
records = records(order);
writeManifestCsv(manifestPath, records);
manifestHash = sha256File(manifestPath);
writeHashFile(hashPath, manifestHash);

categories = string({records.Category});
sourceSeal = struct();
sourceSeal.Algorithm = "SHA-256";
sourceSeal.ManifestPath = ...
    "@CAMPAIGN_ROOT@/release_source_manifest.csv";
sourceSeal.ManifestRelativePath = "release_source_manifest.csv";
sourceSeal.ManifestSHA256 = manifestHash;
sourceSeal.HashPath = ...
    "@CAMPAIGN_ROOT@/release_source_manifest.sha256";
sourceSeal.HashRelativePath = "release_source_manifest.sha256";
sourceSeal.MatPath = ...
    "@CAMPAIGN_ROOT@/release_source_manifest.mat";
sourceSeal.JsonPath = ...
    "@CAMPAIGN_ROOT@/release_source_manifest.json";
sourceSeal.FileCount = numel(records);
sourceSeal.TestArtifactCount = nnz(categories == "test_artifact");
sourceSeal.SealedAt = string(datetime('now', ...
    'TimeZone', 'local'), 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX');
sourceSeal.ReleaseRoot = "@RELEASE_ROOT@";
sourceSeal.AuthorityStatement = [ ...
    "The SHA-256 digest of release_source_manifest.csv is the " ...
    "campaign source authority. No Git commit is claimed for this release."];
sourceSeal.Exclusions = [ ...
    "benchmark-results", "benchmarks/results", ...
    "benchmarks/sensitivity-results", "ctsemo-output", ...
    "diagnostic-artifacts", "generated campaign/output directories"];

save(matPath, 'sourceSeal', 'records', '-v7');
serializable = struct('sourceSeal', sourceSeal, 'records', records);
writeJson(jsonPath, serializable);
end

function specifications = sourceSpecifications(releaseRoot)
specifications = repmat(emptySpecification(), 0, 1);

requiredRootFiles = { ...
    'cTSEMO.m', 'cTSEMOOptions.m', 'README.md', 'CHANGELOG.md', ...
    'CITATION.cff', 'LICENSE', 'NOTICE.md', ...
    'THIRD_PARTY_NOTICES.md'};
for index = 1:numel(requiredRootFiles)
    relativePath = requiredRootFiles{index};
    absolutePath = fullfile(releaseRoot, relativePath);
    if ~isfile(absolutePath)
        error('cTSEMO:SourceSeal:RequiredFileMissing', ...
            'Required release file is missing: %s', relativePath);
    end
    if endsWith(relativePath, '.m')
        category = "public_api";
    else
        category = "documentation";
    end
    specifications(end + 1, 1) = makeSpecification( ...
        category, relativePath, absolutePath); %#ok<AGROW>
end

specifications = appendFiles(specifications, releaseRoot, ...
    fullfile('+ctsemo', '**', '*.m'), "core");
specifications = appendSelectedTree(specifications, releaseRoot, ...
    'diagnostics', ["m", "md"], "diagnostics");
specifications = appendSelectedTree(specifications, releaseRoot, ...
    'examples', ["m", "md"], "examples");
specifications = appendSelectedTree(specifications, releaseRoot, ...
    'benchmarks', strings(0, 1), "benchmarks", ...
    {'results', 'sensitivity-results'});
specifications = appendTestFiles(specifications, releaseRoot);
specifications = appendSelectedTree(specifications, releaseRoot, ...
    'vendor', strings(0, 1), "vendor");

relativePaths = string({specifications.RelativePath});
if numel(unique(lower(relativePaths))) ~= numel(relativePaths)
    error('cTSEMO:SourceSeal:DuplicatePath', ...
        'The source-seal inventory contains a duplicate path.');
end
end

function specifications = appendFiles(specifications, releaseRoot, ...
        relativePattern, category)
listing = dir(fullfile(releaseRoot, relativePattern));
listing = listing(~[listing.isdir]);
for index = 1:numel(listing)
    absolutePath = fullfile(listing(index).folder, listing(index).name);
    relativePath = relativeToRoot(absolutePath, releaseRoot);
    specifications(end + 1, 1) = makeSpecification( ...
        category, relativePath, absolutePath); %#ok<AGROW>
end
end

function specifications = appendSelectedTree(specifications, releaseRoot, ...
        relativeRoot, extensions, category, excludedDirectoryNames)
if nargin < 6
    excludedDirectoryNames = {};
end
treeRoot = fullfile(releaseRoot, relativeRoot);
if ~isfolder(treeRoot)
    return
end
listing = dir(fullfile(treeRoot, '**', '*'));
listing = listing(~[listing.isdir]);
for index = 1:numel(listing)
    absolutePath = fullfile(listing(index).folder, listing(index).name);
    relativePath = relativeToRoot(absolutePath, releaseRoot);
    pathParts = split(string(relativePath), '/');
    if any(ismember(lower(pathParts), ...
            lower(string(excludedDirectoryNames))))
        continue
    end
    if ~isempty(extensions)
        [~, ~, extension] = fileparts(listing(index).name);
        normalizedExtension = erase(lower(string(extension)), '.');
        if ~ismember(normalizedExtension, lower(extensions))
            continue
        end
    end
    specifications(end + 1, 1) = makeSpecification( ...
        category, relativePath, absolutePath); %#ok<AGROW>
end
end

function specifications = appendTestFiles(specifications, releaseRoot)
testRoot = fullfile(releaseRoot, 'tests');
if ~isfolder(testRoot)
    return
end
listing = dir(fullfile(testRoot, '**', '*'));
listing = listing(~[listing.isdir]);
for index = 1:numel(listing)
    absolutePath = fullfile(listing(index).folder, listing(index).name);
    relativePath = relativeToRoot(absolutePath, releaseRoot);
    [~, name, extension] = fileparts(listing(index).name);
    fileName = lower(string(name) + string(extension));
    if strcmpi(extension, '.m')
        category = "test_source";
    elseif fileName == "readme.md"
        category = "test_documentation";
    else
        category = "test_artifact";
    end
    specifications(end + 1, 1) = makeSpecification( ...
        category, relativePath, absolutePath); %#ok<AGROW>
end
end

function specification = makeSpecification(category, ...
        relativePath, absolutePath)
specification = emptySpecification();
specification.Category = string(category);
specification.RelativePath = ...
    replace(string(relativePath), '\', '/');
specification.AbsolutePath = string(absolutePath);
end

function specification = emptySpecification()
specification = struct( ...
    'Category', "", ...
    'RelativePath', "", ...
    'AbsolutePath', "");
end

function record = emptyRecord()
record = struct( ...
    'Category', "", ...
    'RelativePath', "", ...
    'Bytes', 0, ...
    'SHA256', "");
end

function relativePath = relativeToRoot(absolutePath, releaseRoot)
prefix = string(releaseRoot);
absolutePath = string(absolutePath);
if ~startsWith(lower(absolutePath), lower(prefix))
    error('cTSEMO:SourceSeal:PathOutsideRelease', ...
        'Source path lies outside the release root: %s', absolutePath);
end
relativePath = extractAfter(absolutePath, strlength(prefix));
relativePath = strip(relativePath, 'left', filesep);
relativePath = replace(relativePath, '\', '/');
end

function hash = sha256File(pathValue)
messageDigest = java.security.MessageDigest.getInstance('SHA-256');
fileId = fopen(pathValue, 'rb');
if fileId < 0
    error('cTSEMO:SourceSeal:FileOpenFailed', ...
        'Could not open source file for hashing: %s', pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
while ~feof(fileId)
    bytes = fread(fileId, 1024 * 1024, '*uint8');
    if ~isempty(bytes)
        messageDigest.update(typecast(bytes, 'int8'));
    end
end
digest = typecast(messageDigest.digest(), 'uint8');
hash = lower(string(reshape(dec2hex(digest, 2).', 1, [])));
clear cleanup
end

function writeManifestCsv(pathValue, records)
fileId = fopen(pathValue, 'w');
if fileId < 0
    error('cTSEMO:SourceSeal:ManifestOpenFailed', ...
        'Could not open source manifest for writing: %s', pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'Category,RelativePath,Bytes,SHA256\n');
for index = 1:numel(records)
    fprintf(fileId, '"%s","%s",%.0f,"%s"\n', ...
        escapeCsv(records(index).Category), ...
        escapeCsv(records(index).RelativePath), ...
        records(index).Bytes, records(index).SHA256);
end
clear cleanup
end

function writeHashFile(pathValue, manifestHash)
fileId = fopen(pathValue, 'w');
if fileId < 0
    error('cTSEMO:SourceSeal:HashFileOpenFailed', ...
        'Could not open source-manifest hash file: %s', pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s  release_source_manifest.csv\n', manifestHash);
clear cleanup
end

function writeJson(pathValue, value)
encoded = jsonencode(value, 'PrettyPrint', true);
fileId = fopen(pathValue, 'w');
if fileId < 0
    error('cTSEMO:SourceSeal:JsonOpenFailed', ...
        'Could not open source-manifest JSON file: %s', pathValue);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', encoded);
clear cleanup
end

function text = escapeCsv(value)
text = char(replace(string(value), '"', '""'));
end
