classdef BenchmarkRegistryTest < matlab.unittest.TestCase
    %BenchmarkRegistryTest Benchmark definitions and initial-design tests.

    methods (TestClassSetup)
        function addReleaseAndBenchmarkPaths(testCase)
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                releaseRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(releaseRoot, "benchmarks")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(releaseRoot, "examples")));
        end
    end

    methods (Test, TestTags = {'Unit', 'Benchmark'})
        function testCossinInitialDesignIncludesAllCorners(testCase)
            [X, info] = BenchmarkRegistryTest.cossinCornerDesign();

            testCase.verifyEqual(info.IncludedCornerCount, 4);
            testCase.verifyTrue( ...
                all(ismember([0, 0; 0, 1; 1, 0; 1, 1], X, "rows")));
        end

        function testInitialDesignRestoresCallerRng(testCase)
            [before, after] = BenchmarkRegistryTest.rngAroundDesign();

            testCase.verifyEqual(after, before);
        end

        function testLocalLhsIsReproducibleAndStratified(testCase)
            [first, second, strata] = ...
                BenchmarkRegistryTest.localLhsReplicates();

            testCase.verifyEqual(first, second);
            testCase.verifyEqual(strata, repmat((0:9).', 1, 2));
        end

        function testBnhAllInfeasibleStressDesign(testCase)
            [labels, info] = BenchmarkRegistryTest.bnhInfeasibleDesign();

            testCase.verifyFalse(any(labels));
            testCase.verifyEqual(info.FeasibleCount, 0);
            testCase.verifyEqual(info.ViolatingCount, 8);
        end

        function testWeldedBeamDefinitionHasFourVariables(testCase)
            [dimension, objectiveSize, constraintSize] = ...
                BenchmarkRegistryTest.weldedBeamSizes();

            testCase.verifyEqual(dimension, 4);
            testCase.verifyEqual(objectiveSize, [2, 2]);
            testCase.verifyEqual(constraintSize, [2, 4]);
        end

        function testC2Dtlz2DefinitionHasThreeVariables(testCase)
            [dimension, objectiveSize, labelSize] = ...
                BenchmarkRegistryTest.c2Dtlz2Sizes();

            testCase.verifyEqual(dimension, 3);
            testCase.verifyEqual(objectiveSize, [2, 2]);
            testCase.verifyEqual(labelSize, [2, 1]);
        end

        function testHighDimensionalDefinitionsAreVectorized(testCase)
            [dimensions, objectiveColumns, constraintColumns, ...
                labelAgreement] = ...
                BenchmarkRegistryTest.highDimensionalContracts();

            testCase.verifyEqual(dimensions, [6, 6, 6, 10]);
            testCase.verifyEqual(objectiveColumns, [2, 2, 2, 2]);
            testCase.verifyEqual(constraintColumns, [1, 6, 2, 1]);
            testCase.verifyTrue(all(labelAgreement));
        end

        function testFourDimensionalDefinitionContracts(testCase)
            [dimensions, objectiveSizes, marginSizes, labelSizes, ...
                labelAgreement] = ...
                BenchmarkRegistryTest.fourDimensionalContracts();

            testCase.verifyEqual(dimensions, [4, 4, 4]);
            testCase.verifyEqual(objectiveSizes, repmat([3, 2], 3, 1));
            testCase.verifyEqual(marginSizes, [3, 1; 3, 2; 3, 1]);
            testCase.verifyEqual(labelSizes, repmat([3, 1], 3, 1));
            testCase.verifyTrue(all(labelAgreement));
        end

        function testFourDimensionalDefinitionsAreVectorized(testCase)
            [objectiveError, marginError, labelAgreement] = ...
                BenchmarkRegistryTest.fourDimensionalVectorization();

            testCase.verifyLessThanOrEqual(objectiveError, 1.0e-12);
            testCase.verifyLessThanOrEqual(marginError, 1.0e-12);
            testCase.verifyTrue(all(labelAgreement));
        end

        function testFourDimensionalAliasesResolve(testCase)
            [resolvedIds, objectiveAgreement, marginAgreement] = ...
                BenchmarkRegistryTest.fourDimensionalAliasEvidence();

            testCase.verifyEqual(resolvedIds, ...
                ["C2DTLZ2_D4_R02", "MW7_D4", "CF1_D4"]);
            testCase.verifyTrue(all(objectiveAgreement));
            testCase.verifyTrue(all(marginAgreement));
        end

        function testHighDimensionalReferencePointsMatchEquations(testCase)
            [c2Objective, c2Margin, osyObjective, osyMargins] = ...
                BenchmarkRegistryTest.highDimensionalReferenceValues();

            testCase.verifyEqual(c2Objective, [1, 0], ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(c2Margin, -0.04, ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(osyObjective, [-9, 51], ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(osyMargins, ...
                [-2, -2, -2, -6, -1, 0], ...
                AbsTol=1.0e-12);
        end

        function testSmokeRunnerRejectsUnknownOptions(testCase)
            testCase.verifyError( ...
                @BenchmarkRegistryTest.invokeUnknownSmokeOption, ...
                "cTSEMO:SmokeUnknownOption");
        end

        function testWeldedBeamSensitivityProfilesParse(testCase)
            [shipped, shippedOptions] = ...
                weldedBeamSensitivityProfile("shipped", "unused");
            [higher, higherOptions] = ...
                weldedBeamSensitivityProfile("higher_compute", "unused");

            testCase.verifyEqual( ...
                shippedOptions.feasibility.inputEncoding, "feasibleIsOne");
            testCase.verifyEqual( ...
                higherOptions.feasibility.inputEncoding, "feasibleIsOne");
            testCase.verifyEqual( ...
                shippedOptions.candidates.primaryCount, 1024);
            testCase.verifyEqual( ...
                shippedOptions.challengers.count, 512);
            testCase.verifyEqual( ...
                shippedOptions.objectiveGP.nFeatures, 256);
            testCase.verifyEqual( ...
                higherOptions.candidates.primaryCount, 2048);
            testCase.verifyEqual( ...
                higherOptions.challengers.count, 1024);
            testCase.verifyEqual( ...
                higherOptions.objectiveGP.nFeatures, 1000);
            testCase.verifyFalse( ...
                isfield(shippedOptions.challengers, "refineCount"));
            testCase.verifyEqual(shipped.Id, "shipped");
            testCase.verifyEqual(higher.Id, "higher_compute");
        end

        function testSourceSealIsPortableAndSelfConsistent(testCase)
            evidence = BenchmarkRegistryTest.sourceSealEvidence(testCase);

            testCase.verifyTrue(all(evidence.FilesExist));
            testCase.verifyEqual( ...
                evidence.RecomputedHash, evidence.RecordedHash);
            testCase.verifyTrue(evidence.PathsAreRelative);
            testCase.verifyTrue(evidence.ExpectedExclusionsHold);
            testCase.verifyGreaterThanOrEqual( ...
                evidence.TestArtifactCount, 1);
        end

        function testSummarizerResolvesPortableCampaignToken(testCase)
            evidence = ...
                BenchmarkRegistryTest.portableSummaryEvidence(testCase);

            testCase.verifyTrue(all(evidence.FilesExist));
            testCase.verifyEqual(evidence.RowCount, 1);
            testCase.verifyEqual(evidence.CaseId, "TOKEN_CASE");
            testCase.verifyEqual(evidence.RunDirectory, ...
                "@CAMPAIGN_ROOT@/01_TOKEN_CASE/run");
        end
    end

    methods (Static, Access = private)
        function [X, info] = cossinCornerDesign()
            problem = getBenchmarkProblem("COSSIN2");
            [X, info] = initialDesign(problem, 8, 7);
        end

        function [before, after] = rngAroundDesign()
            problem = getBenchmarkProblem("COSSIN1");
            rng(91, "twister");
            before = rng;
            initialDesign(problem, 8, 7);
            after = rng;
        end

        function [first, second, sortedStrata] = localLhsReplicates()
            problem = getBenchmarkProblem("COSSIN1");
            options = struct("IncludeCorners", false);
            first = initialDesign(problem, 10, 801, options);
            second = initialDesign(problem, 10, 801, options);
            unit = (first - problem.lowerBound) ./ ...
                (problem.upperBound - problem.lowerBound);
            sortedStrata = sort(floor(10 .* unit), 1);
        end

        function [labels, info] = bnhInfeasibleDesign()
            problem = getBenchmarkProblem("BNH");
            [X, info] = initialDesign( ...
                problem, 8, 7, struct("AllInfeasible", true));
            labels = problem.feasible(X);
        end

        function [dimension, objectiveSize, constraintSize] = ...
                weldedBeamSizes()
            problem = getBenchmarkProblem("WELDEDBEAM");
            X = [problem.lowerBound; problem.upperBound];
            objectiveSize = size(problem.objective(X));
            constraintSize = size(problem.constraintMargins(X));
            dimension = problem.dimension;
        end

        function [dimension, objectiveSize, labelSize] = c2Dtlz2Sizes()
            problem = getBenchmarkProblem("C2DTLZ2");
            X = [problem.lowerBound; problem.upperBound];
            objectiveSize = size(problem.objective(X));
            labelSize = size(problem.label01(X));
            dimension = problem.dimension;
        end

        function [dimensions, objectiveColumns, constraintColumns, ...
                labelAgreement] = highDimensionalContracts()
            identifiers = [ ...
                "C2DTLZ2_D6_R02", "OSY", "MW7_D6", "CF1_D10"];
            dimensions = zeros(1, numel(identifiers));
            objectiveColumns = zeros(1, numel(identifiers));
            constraintColumns = zeros(1, numel(identifiers));
            labelAgreement = false(1, numel(identifiers));
            for index = 1:numel(identifiers)
                problem = getBenchmarkProblem(identifiers(index));
                X = [problem.lowerBound; ...
                    0.5 .* (problem.lowerBound + problem.upperBound); ...
                    problem.upperBound];
                margins = problem.constraintMargins(X);
                dimensions(index) = problem.dimension;
                objectiveColumns(index) = ...
                    size(problem.objective(X), 2);
                constraintColumns(index) = size(margins, 2);
                labelAgreement(index) = isequal( ...
                    logical(problem.label01(X)), ...
                    all(isfinite(margins) & margins <= 0, 2));
            end
        end

        function [c2Objective, c2Margin, osyObjective, osyMargins] = ...
                highDimensionalReferenceValues()
            c2 = getBenchmarkProblem("C2DTLZ2_D6_R02");
            c2X = [0, repmat(0.5, 1, 5)];
            c2Objective = c2.objective(c2X);
            c2Margin = c2.constraintMargins(c2X);

            osy = getBenchmarkProblem("OSY");
            osyX = [2, 2, 3, 3, 3, 4];
            osyObjective = osy.objective(osyX);
            osyMargins = osy.constraintMargins(osyX);
        end

        function [dimensions, objectiveSizes, marginSizes, labelSizes, ...
                labelAgreement] = fourDimensionalContracts()
            identifiers = ["C2DTLZ2_D4_R02", "MW7_D4", "CF1_D4"];
            dimensions = zeros(1, numel(identifiers));
            objectiveSizes = zeros(numel(identifiers), 2);
            marginSizes = zeros(numel(identifiers), 2);
            labelSizes = zeros(numel(identifiers), 2);
            labelAgreement = false(1, numel(identifiers));
            for index = 1:numel(identifiers)
                problem = getBenchmarkProblem(identifiers(index));
                X = [problem.lowerBound; ...
                    0.5 .* (problem.lowerBound + problem.upperBound); ...
                    problem.upperBound];
                objectives = problem.objective(X);
                margins = problem.constraintMargins(X);
                labels = problem.label01(X);
                dimensions(index) = problem.dimension;
                objectiveSizes(index, :) = size(objectives);
                marginSizes(index, :) = size(margins);
                labelSizes(index, :) = size(labels);
                labelAgreement(index) = isequal( ...
                    logical(labels), ...
                    all(isfinite(margins) & margins <= 0, 2));
            end
        end

        function [objectiveError, marginError, labelAgreement] = ...
                fourDimensionalVectorization()
            identifiers = ["C2DTLZ2_D4_R02", "MW7_D4", "CF1_D4"];
            objectiveError = zeros(1, numel(identifiers));
            marginError = zeros(1, numel(identifiers));
            labelAgreement = false(1, numel(identifiers));
            for index = 1:numel(identifiers)
                problem = getBenchmarkProblem(identifiers(index));
                X = [problem.lowerBound; ...
                    0.37 .* problem.lowerBound + ...
                    0.63 .* problem.upperBound; ...
                    problem.upperBound];
                vectorObjectives = problem.objective(X);
                rowObjectives = [ ...
                    problem.objective(X(1, :)); ...
                    problem.objective(X(2, :)); ...
                    problem.objective(X(3, :))];
                vectorMargins = problem.constraintMargins(X);
                rowMargins = [ ...
                    problem.constraintMargins(X(1, :)); ...
                    problem.constraintMargins(X(2, :)); ...
                    problem.constraintMargins(X(3, :))];
                objectiveError(index) = max(abs( ...
                    vectorObjectives - rowObjectives), [], "all");
                marginError(index) = max(abs( ...
                    vectorMargins - rowMargins), [], "all");
                labelAgreement(index) = isequal( ...
                    problem.label01(X), ...
                    [problem.label01(X(1, :)); ...
                    problem.label01(X(2, :)); ...
                    problem.label01(X(3, :))]);
            end
        end

        function [resolvedIds, objectiveAgreement, marginAgreement] = ...
                fourDimensionalAliasEvidence()
            canonicalIds = ["C2DTLZ2_D4_R02", "MW7_D4", "CF1_D4"];
            aliases = ["C2DTLZ2_D4", "MW7-D4", "CF1D4"];
            resolvedIds = strings(1, numel(canonicalIds));
            objectiveAgreement = false(1, numel(canonicalIds));
            marginAgreement = false(1, numel(canonicalIds));
            for index = 1:numel(canonicalIds)
                canonical = getBenchmarkProblem(canonicalIds(index));
                alias = getBenchmarkProblem(aliases(index));
                X = 0.41 .* canonical.lowerBound + ...
                    0.59 .* canonical.upperBound;
                resolvedIds(index) = string(alias.id);
                objectiveAgreement(index) = isequal( ...
                    alias.objective(X), canonical.objective(X));
                marginAgreement(index) = isequal( ...
                    alias.constraintMargins(X), ...
                    canonical.constraintMargins(X));
            end
        end

        function invokeUnknownSmokeOption()
            runSmokeBenchmarks("COSSIN1", ...
                struct("NotARunnerOption", true));
        end

        function evidence = sourceSealEvidence(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            [seal, records] = sealReleaseSourceManifest( ...
                releaseRoot, fixture.Folder);
            names = ["release_source_manifest.csv", ...
                "release_source_manifest.sha256", ...
                "release_source_manifest.mat", ...
                "release_source_manifest.json"];
            relativePaths = string({records.RelativePath});
            forbidden = ["benchmark-results/", "benchmarks/results/", ...
                "benchmarks/sensitivity-results/", ...
                "ctsemo-output/", "diagnostic-artifacts/"];
            excluded = true;
            for index = 1:numel(forbidden)
                excluded = excluded && ...
                    ~any(startsWith(relativePaths, forbidden(index)));
            end
            evidence = struct( ...
                "FilesExist", arrayfun(@(name) ...
                isfile(fullfile(fixture.Folder, name)), names), ...
                "RecomputedHash", ...
                BenchmarkRegistryTest.fileSha256(fullfile( ...
                fixture.Folder, "release_source_manifest.csv")), ...
                "RecordedHash", seal.ManifestSHA256, ...
                "PathsAreRelative", ...
                all(~contains(relativePaths, ":") & ...
                ~startsWith(relativePaths, "/") & ...
                ~startsWith(relativePaths, "\")), ...
                "ExpectedExclusionsHold", excluded, ...
                "TestArtifactCount", seal.TestArtifactCount);
        end

        function evidence = portableSummaryEvidence(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            campaignRoot = fixture.Folder;
            caseRoot = fullfile(campaignRoot, "01_TOKEN_CASE");
            runRoot = fullfile(caseRoot, "run");
            mkdir(runRoot);

            manifest = struct( ...
                "CampaignId", "token_campaign", ...
                "CaseIndex", 1, ...
                "CaseId", "TOKEN_CASE", ...
                "ProblemId", "TOKEN_CASE", ...
                "Status", "completed", ...
                "AllInfeasibleStress", false, ...
                "InitialSeed", 1, ...
                "SolverSeed", 2, ...
                "InitialCount", 1, ...
                "SequentialBudget", 0, ...
                "InitialFeasibleCount", 1, ...
                "LoggingLevel", "summary", ...
                "PrimaryCandidateCount", 8, ...
                "ChallengerCandidateCount", 4, ...
                "ObjectiveFeatureCount", 16, ...
                "RunDirectory", ...
                "@CAMPAIGN_ROOT@/01_TOKEN_CASE/run", ...
                "ResultFile", ...
                "@CAMPAIGN_ROOT@/01_TOKEN_CASE/run/result.mat", ...
                "ErrorIdentifier", "", ...
                "ErrorMessage", "");
            save(fullfile(caseRoot, "case_manifest.mat"), ...
                "manifest", "-v7");

            result = struct();
            result.data = struct( ...
                "X", zeros(1, 2), ...
                "isFeasible", true, ...
                "nInitial", 1);
            result.iterations = [];
            result.meta = struct( ...
                "completedEvaluations", 0, ...
                "wallTimeSeconds", 0);
            result.pareto = struct( ...
                "nPoints", 1, ...
                "hypervolume", 0, ...
                "referencePoint", [1, 1]);
            save(fullfile(runRoot, "result.mat"), "result", "-v7");

            summary = summarizeReleaseBenchmarks(campaignRoot);
            evidence = struct( ...
                "FilesExist", [ ...
                isfile(fullfile(campaignRoot, "campaign_summary.csv")), ...
                isfile(fullfile(campaignRoot, "campaign_summary.mat")), ...
                isfile(fullfile(runRoot, "summary.csv"))], ...
                "RowCount", height(summary), ...
                "CaseId", summary.CaseId(1), ...
                "RunDirectory", summary.RunDirectory(1));
        end

        function hash = fileSha256(pathValue)
            messageDigest = java.security.MessageDigest.getInstance( ...
                'SHA-256');
            fileId = fopen(pathValue, 'rb');
            cleanup = onCleanup(@() fclose(fileId));
            while ~feof(fileId)
                bytes = fread(fileId, 1024 * 1024, '*uint8');
                if ~isempty(bytes)
                    messageDigest.update(typecast(bytes, 'int8'));
                end
            end
            digest = typecast(messageDigest.digest(), 'uint8');
            hash = lower(string( ...
                reshape(dec2hex(digest, 2).', 1, [])));
            clear cleanup
        end
    end
end
