function manifest = update_artifact_manifest
%UPDATE_ARTIFACT_MANIFEST Rebuild the curated manuscript evidence index.
%   MANIFEST = UPDATE_ARTIFACT_MANIFEST() records repository-relative paths,
%   byte counts, SHA-256 digests, roles, generators, and manuscript references
%   for the retained evidence files.

artifactDirectory = string(fileparts(mfilename("fullpath")));
manuscriptDirectory = string(fileparts(artifactDirectory));
repositoryRoot = string(fileparts(manuscriptDirectory));
introductionDirectory = fullfile( ...
    manuscriptDirectory, "introduction_pof_comparison", "output");
hullDataDirectory = fullfile( ...
    repositoryRoot, "studies", "hull_coverage", "data");
manifestPath = fullfile(artifactDirectory, "artifact_manifest.csv");

files = [ ...
    dir(fullfile(artifactDirectory, "**", "*")); ...
    dir(fullfile(introductionDirectory, "*")); ...
    dir(fullfile(hullDataDirectory, "*"))];
files = files(~[files.isdir]);

absolutePaths = string(fullfile({files.folder}, {files.name}))';
relativePaths = replace(erase( ...
    absolutePaths, repositoryRoot + filesep), "\", "/");
keep = relativePaths ~= ...
    "manuscript/artifacts/artifact_manifest.csv";
keep = keep & ~contains(relativePaths, ...
    "/two_dimensional_campaign/grids/");
keep = keep & ~endsWith(relativePaths, ...
    "/introduction_pof_comparison/output/pof_comparison_data.mat");
generatedHighDimensional = contains(relativePaths, ...
    "/ga_primary_dimension/ga_primary_highdim_") & ...
    (endsWith(relativePaths, ".png") | endsWith(relativePaths, ".pdf"));
keep = keep & ~generatedHighDimensional;
keep = keep & ~endsWith(relativePaths, ...
    "/two_dimensional_campaign/figure_manifest.csv");
keep = keep & ~(endsWith(relativePaths, ".png") & ...
    ~endsWith(relativePaths, "classification_error_maps_source.png"));
keep = keep & ~any(endsWith(relativePaths, ...
    ["cossin_pof_learning_maps.pdf", ...
     "final_classification_error_maps.pdf", ...
     "final_prediction_truth_maps.pdf"]), 2);
files = files(keep);
absolutePaths = absolutePaths(keep);
relativePaths = relativePaths(keep);

rowCount = numel(relativePaths);
category = strings(rowCount, 1);
status = strings(rowCount, 1);
manuscriptReference = strings(rowCount, 1);
generator = strings(rowCount, 1);
bytes = [files.bytes]';
sha256 = strings(rowCount, 1);

for fileIndex = 1:rowCount
    category(fileIndex) = categoryForPath(relativePaths(fileIndex));
    [status(fileIndex), manuscriptReference(fileIndex)] = ...
        evidenceForPath(relativePaths(fileIndex));
    generator(fileIndex) = generatorForPath(relativePaths(fileIndex));
    sha256(fileIndex) = sha256File(absolutePaths(fileIndex));
end

manifest = table( ...
    relativePaths, category, bytes, sha256, status, ...
    manuscriptReference, generator, ...
    VariableNames=[ ...
        "RelativePath", "Category", "Bytes", "Sha256", "Status", ...
        "ManuscriptReference", "Generator"]);
manifest = sortrows(manifest, "RelativePath");
writetable(manifest, manifestPath);

fprintf("Artifact manifest updated: %d files\n", height(manifest));
fprintf("  %s\n", manifestPath);
end

function category = categoryForPath(relativePath)
if startsWith(relativePath, ...
        "manuscript/introduction_pof_comparison/output/")
    category = "introduction";
elseif contains(relativePath, "/ga_primary_challenger/")
    category = "ga_primary_challenger";
elseif contains(relativePath, "/two_dimensional_campaign/")
    category = "two_dimensional";
elseif contains(relativePath, "/finite_primary_ablation/")
    category = "finite_primary_ablation";
elseif contains(relativePath, "/wb150_thesis/")
    category = "wb150_thesis";
elseif contains(relativePath, "/ga_primary_dimension/")
    category = "ga_primary_dimension";
elseif contains(relativePath, "/hull_coverage/")
    category = "hull_coverage";
elseif contains(relativePath, "/tests/")
    category = "tests";
else
    category = "index";
end
end

function [status, reference] = evidenceForPath(relativePath)
status = "supporting";
reference = "";
[~, baseName, extension] = fileparts(relativePath);
fileName = string(baseName) + string(extension);

switch fileName
    case "table1_pof_atlas.pdf"
        status = "cited";
        reference = "Figure 1";
    case "gpc_ctsemo_pof_comparison.pdf"
        status = "cited";
        reference = "Figure 2";
    case "ga_primary_challenger_summary.csv"
        status = "cited";
        reference = "Table 5";
    case "campaign_summary.csv"
        status = "cited";
        if contains(relativePath, "/ga_primary_challenger/")
            reference = "Table 5 and Section 5.1";
        else
            reference = "Table 6 and Section 5.2";
        end
    case "pof_metrics.csv"
        status = "cited";
        reference = "Table 6 and Section 5.2";
    case "final_pof_maps.pdf"
        status = "cited";
        reference = "Figure 4";
    case "cossin2_acquisition_decomposition.pdf"
        status = "cited";
        reference = "Figure 5";
    case "cossin1_learning.pdf"
        status = "cited";
        reference = "Figure 6";
    case "cossin2_learning.pdf"
        status = "cited";
        reference = "Figure 7";
    case "classification_error_maps.pdf"
        status = "cited";
        reference = "Figure 8";
    case {"field_metrics.csv", "paired_aggregate_summary.csv", ...
            "paired_dimension_gp_rf_metrics.pdf"}
        status = "cited";
        reference = "Table 7 and Figures 9-10";
    case {"ga_primary_highdim_summary.csv", ...
            "ga_primary_highdim_per_run.csv"}
        status = "cited";
        reference = "Table 8 and Section 6.2";
    case {"selection_state_per_run.csv", "selection_state_totals.csv"}
        status = "cited";
        reference = "Thesis Chapter 3 higher-dimensional selection states";
    case {"problem_ga_vs_finite_pool_pf_comparison.csv", ...
            "paired_ga_vs_finite_pool_pf_comparison.csv"}
        status = "cited";
        reference = "Thesis Table 3.6";
    case {"wb150_selected_iteration.csv", ...
            "ctsemo_wb150_hvi_profiles.csv", ...
            "ctsemo_wb150_hvi_pairwise.csv", ...
            "ctsemo_wb150_hvi_reconstruction_validation.csv", ...
            "ctsemo_wb150_hvi_conditional_x1.csv", ...
            "ctsemo_wb150_hvi_conditional_x2.csv", ...
            "ctsemo_wb150_hvi_conditional_x3.csv", ...
            "ctsemo_wb150_hvi_conditional_x4.csv"}
        status = "cited";
        reference = "Thesis Section 3.8 and Figures 3.8-3.12";
    case {"ctsemo_wb150_hvi_profiles.pdf", ...
            "ctsemo_wb150_hvi_pairwise.pdf", ...
            "ctsemo_wb150_hvi_conditional_x1.pdf", ...
            "ctsemo_wb150_hvi_conditional_x2.pdf", ...
            "ctsemo_wb150_hvi_conditional_x3.pdf", ...
            "ctsemo_wb150_hvi_conditional_x4.pdf"}
        status = "cited";
        reference = "Thesis Figures 3.8-3.12";
    case "hypervolume_histories.pdf"
        status = "cited";
        reference = "Figures 11-12";
    case "dimension_hull_coverage.pdf"
        status = "cited";
        reference = "Figure 13";
    case {"convex_hull_growth.csv", "maximum_simplex_volume.csv"}
        status = "cited";
        reference = "Figure 13";
end
end

function generator = generatorForPath(relativePath)
if startsWith(relativePath, ...
        "manuscript/introduction_pof_comparison/output/")
    generator = ...
        "manuscript/introduction_pof_comparison/run_introduction_pof_comparison.m";
elseif contains(relativePath, "/ga_primary_challenger/")
    generator = "src/benchmarks/runReleaseBenchmarks.m";
elseif contains(relativePath, "/two_dimensional_campaign/")
    generator = ...
        "studies/two_dimensional_pof/reproduce_two_dimensional_pof_results.m";
    if contains(relativePath, "cossin2_acquisition_decomposition")
        generator = ...
            "studies/two_dimensional_pof/make_cossin2_acquisition_decomposition.py";
    elseif contains(relativePath, "classification_error_maps")
        generator = ...
            "studies/two_dimensional_pof/build_shared_classification_legend.py";
    end
elseif contains(relativePath, "/ga_primary_dimension/")
    generator = "studies/dimension_matched_pof/launch_full_study.m";
    if contains(relativePath, "hypervolume_histories")
        generator = ...
            "manuscript/artifacts/ga_primary_dimension/reproduce_highdimensional_results.m";
    end
elseif contains(relativePath, "/finite_primary_ablation/")
    generator = ...
        "manuscript/artifacts/finite_primary_ablation/reproduce_finite_primary_ablation.m";
elseif contains(relativePath, "/wb150_thesis/")
    generator = ...
        "manuscript/artifacts/wb150_thesis/generate_wb150_thesis_artifacts.m";
elseif contains(relativePath, "/hull_coverage/")
    generator = "studies/hull_coverage/plot_dimension_hull_coverage.py";
elseif contains(relativePath, "/tests/")
    generator = "run_release_tests.m";
else
    generator = "manual index";
end
end

function digest = sha256File(pathValue)
engine = java.security.MessageDigest.getInstance("SHA-256");
fileId = fopen(pathValue, "rb");
assert(fileId >= 0, "Could not open %s for hashing.", pathValue);
cleanup = onCleanup(@() fclose(fileId));
while ~feof(fileId)
    chunk = fread(fileId, 1024 * 1024, "*uint8");
    if ~isempty(chunk)
        engine.update(typecast(chunk, "int8"));
    end
end
rawDigest = typecast(engine.digest(), "uint8");
digest = lower(string(reshape(dec2hex(rawDigest, 2).', 1, [])));
clear cleanup
end
