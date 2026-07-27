function results = run_repository_tests
%RUN_REPOSITORY_TESTS Run all bundled cTSEMO MATLAB tests.

repositoryRoot = setup_ctsemo();
testDirectory = fullfile(repositoryRoot, "src", "tests");
results = runtests(testDirectory, "IncludeSubfolders", true);

if any([results.Failed])
    error("cTSEMO:RepositoryTests:Failure", ...
        "%d of %d tests failed.", nnz([results.Failed]), numel(results));
end
end
