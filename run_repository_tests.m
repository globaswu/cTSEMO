function results = run_repository_tests
%RUN_REPOSITORY_TESTS Run all bundled cTSEMO MATLAB tests.

repositoryRoot = setup_ctsemo();
testDirectory = fullfile(repositoryRoot, "src", "tests");
originalDirectory = pwd;
workDirectory = tempname;
mkdir(workDirectory);
cleanup = onCleanup(@() restoreTestEnvironment( ...
    originalDirectory, workDirectory));
cd(workDirectory);
results = runtests(testDirectory, "IncludeSubfolders", true);

if any([results.Failed])
    error("cTSEMO:RepositoryTests:Failure", ...
        "%d of %d tests failed.", nnz([results.Failed]), numel(results));
end

clear cleanup
end

function restoreTestEnvironment(originalDirectory, workDirectory)
cd(originalDirectory);
if isfolder(workDirectory)
    rmdir(workDirectory, "s");
end
end
