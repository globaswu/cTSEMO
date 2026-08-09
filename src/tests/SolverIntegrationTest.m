classdef SolverIntegrationTest < matlab.unittest.TestCase
    %SolverIntegrationTest Small end-to-end cTSEMO release tests.

    methods (TestClassSetup)
        function addReleaseAndBenchmarkPaths(testCase)
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                releaseRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(releaseRoot, "benchmarks")));
        end
    end

    methods (Test, TestTags = {'Integration'})
        function testTinyCossinRunCompletesRequestedBudget(testCase)
            result = SolverIntegrationTest.tinyCossinRun();

            testCase.verifyEqual(result.meta.status, "completed");
            testCase.verifyEqual(result.meta.completedEvaluations, 2);
            testCase.verifyEqual(numel(result.iterations), 2);
            testCase.verifyEqual(size(result.data.X, 1), 10);
            testCase.verifyEqual(size(result.data.Y, 1), 10);
            testCase.verifyEqual(numel(result.data.isFeasible), 10);
        end

        function testTinyCossinRunStaysWithinBounds(testCase)
            [minimumSlack, maximumExcess] = ...
                SolverIntegrationTest.cossinBoundResiduals();

            testCase.verifyGreaterThanOrEqual(minimumSlack, ...
                -1.0e-12);
            testCase.verifyLessThanOrEqual(maximumExcess, ...
                1.0e-12);
        end

        function testTinyCossinRunDoesNotRepeatDesigns(testCase)
            minimumDistance = ...
                SolverIntegrationTest.cossinMinimumPairDistance();

            testCase.verifyGreaterThan(minimumDistance, 1.0e-9);
        end

        function testAllInfeasibleBnhUsesPhaseOneFallback(testCase)
            [record, initialFeasibleCount] = ...
                SolverIntegrationTest.allInfeasibleBnhRun();

            testCase.verifyEqual(initialFeasibleCount, 0);
            testCase.verifyEqual(record.selectionState, ...
                "feasibilityDiscovery");
            testCase.verifyEqual(record.selectionSource, "fallback");
            testCase.verifyTrue(record.fallbackUsed);
            testCase.verifyEqual(record.fallbackReason, ...
                "noFeasibleObservation");
        end

        function testAllInfeasibleBnhStillCompletesEvaluation(testCase)
            result = SolverIntegrationTest.allInfeasibleBnhResult();

            testCase.verifyEqual(result.meta.status, "completed");
            testCase.verifyEqual(result.meta.completedEvaluations, 1);
            testCase.verifyEqual(size(result.data.X, 1), 9);
        end

        function testRepeatedInfeasibleObservationsRemainInPhaseOne( ...
                testCase)
            [states, sources, reasons, labels] = ...
                SolverIntegrationTest.repeatedInfeasibleRun();

            testCase.verifyEqual(states, repmat( ...
                "feasibilityDiscovery", 2, 1));
            testCase.verifyEqual(sources, repmat("fallback", 2, 1));
            testCase.verifyEqual(reasons, repmat( ...
                "noFeasibleObservation", 2, 1));
            testCase.verifyFalse(any(labels));
        end

        function testUnconstrainedRunRetainsObjectiveTsPath(testCase)
            record = SolverIntegrationTest.unconstrainedRecord();

            testCase.verifyNotEqual(record.selectionState, ...
                "feasibilityDiscovery");
            testCase.verifyEqual(record.selected.pof, 1, ...
                AbsTol=eps);
            testCase.verifyEqual(record.selected.rawPof, 1.25, ...
                AbsTol=eps);
            testCase.verifyTrue(all(isfinite(record.selected.YDraw)));
        end

        function testSequentialAutoRejectsAmbiguousNumericLabels(testCase)
            testCase.verifyError( ...
                SolverIntegrationTest.autoAmbiguousRuntimeCall(), ...
                "cTSEMO:Inputs:AmbiguousNumericLabels");
        end

        function testSequentialExplicitBinaryEncodingsAreHonored(testCase)
            labels = SolverIntegrationTest.explicitRuntimeLabels();

            testCase.verifyEqual(labels, logical([1; 1]));
        end

        function testStoredSampledHviAndAcquisitionReconstruct( ...
                testCase)
            [storedHvi, reconstructedHvi, storedAF, ...
                reconstructedAF, storedStandardizedDraw, ...
                reconstructedStandardizedDraw] = ...
                SolverIntegrationTest.reconstructedAcquisition();

            testCase.verifyEqual(storedHvi, reconstructedHvi, ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(storedAF, reconstructedAF, ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(storedStandardizedDraw, ...
                reconstructedStandardizedDraw, AbsTol=1.0e-12);
        end

        function testFeasibleRunUsesGaPrimaryAndLhsChallenger(testCase)
            [primaryCount, challengerCount, searchMethod, ...
                    searchStatus, primaryOrigin, returnedSeedBest, ...
                    searchBestScore, primaryAF, challengerOrigins] = ...
                SolverIntegrationTest.finalCandidateCounts();

            testCase.verifyEqual(primaryCount, 1);
            testCase.verifyEqual(challengerCount, 24);
            testCase.verifyEqual(searchMethod, "ga");
            testCase.verifyEqual(searchStatus, "completed");
            testCase.verifyEqual(primaryOrigin, "primary_seed");
            testCase.verifyTrue(returnedSeedBest);
            testCase.verifyEqual(searchBestScore, primaryAF, ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(challengerOrigins, ...
                repmat("lhs", challengerCount, 1));
        end

        function testPoolAblationRecordsConsistentPrimaryDiagnostics( ...
                testCase)
            [status, seedBestScore, bestScore, improvement, ...
                    returnedSeedBest] = ...
                SolverIntegrationTest.poolModeDiagnostics();

            testCase.verifyEqual(status, "pool");
            testCase.verifyEqual(seedBestScore, bestScore, ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(improvement, 0, AbsTol=eps);
            testCase.verifyTrue(returnedSeedBest);
        end

        function testSelectedPointIsGlobalCompletePoolMaximum(testCase)
            [storedMaximum, selectedAF, selectedSource, ...
                sourceAtMaximum, fallbackUsed] = ...
                SolverIntegrationTest.completePoolMaximum();

            testCase.verifyFalse(fallbackUsed);
            testCase.verifyEqual(selectedAF, storedMaximum, ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(selectedSource, sourceAtMaximum);
        end

        function testTenDimensionalCf1RunIsLabelConsistent(testCase)
            [status, dimension, evaluationCount, labelsAgree] = ...
                SolverIntegrationTest.tenDimensionalCf1Evidence();

            testCase.verifyEqual(status, "completed");
            testCase.verifyEqual(dimension, 10);
            testCase.verifyEqual(evaluationCount, 21);
            testCase.verifyTrue(labelsAgree);
        end
    end

    methods (Static, Access = private)
        function result = tinyCossinRun()
            persistent cachedResult
            if isempty(cachedResult)
                problem = getBenchmarkProblem("COSSIN1");
                X0 = initialDesign(problem, 8, 13);
                Y0 = problem.objective(X0);
                C0 = problem.feasible(X0);
                cachedResult = cTSEMO( ...
                    problem.objective, problem.feasible, ...
                    X0, Y0, C0, ...
                    problem.lowerBound, problem.upperBound, ...
                    SolverIntegrationTest.fastOptions(2, 41));
            end
            result = cachedResult;
        end

        function [minimumSlack, maximumExcess] = cossinBoundResiduals()
            result = SolverIntegrationTest.tinyCossinRun();
            problem = getBenchmarkProblem("COSSIN1");
            slack = result.data.X - problem.lowerBound;
            excess = result.data.X - problem.upperBound;
            minimumSlack = min(slack, [], "all");
            maximumExcess = max(excess, [], "all");
        end

        function distance = cossinMinimumPairDistance()
            result = SolverIntegrationTest.tinyCossinRun();
            X = result.data.X;
            squaredDistance = sum(X.^2, 2) + ...
                sum(X.^2, 2)' - 2 .* (X * X');
            squaredDistance(1:size(X, 1)+1:end) = Inf;
            distance = sqrt(min(max(0, squaredDistance), [], "all"));
        end

        function [record, initialFeasibleCount] = ...
                allInfeasibleBnhRun()
            result = SolverIntegrationTest.allInfeasibleBnhResult();
            initialFeasibleCount = nnz( ...
                result.data.isFeasible(1:result.data.nInitial));
            record = result.iterations(1);
        end

        function result = allInfeasibleBnhResult()
            persistent cachedResult
            if isempty(cachedResult)
                problem = getBenchmarkProblem("BNH");
                X0 = initialDesign(problem, 8, 7, ...
                    struct("AllInfeasible", true));
                Y0 = problem.objective(X0);
                C0 = problem.feasible(X0);
                cachedResult = cTSEMO( ...
                    problem.objective, problem.feasible, ...
                    X0, Y0, C0, ...
                    problem.lowerBound, problem.upperBound, ...
                    SolverIntegrationTest.fastOptions(1, 43));
            end
            result = cachedResult;
        end

        function [states, sources, reasons, labels] = ...
                repeatedInfeasibleRun()
            X0 = [0, 0; 0, 1; 1, 0; 1, 1];
            Y0 = SolverIntegrationTest.unconstrainedObjectives(X0);
            result = cTSEMO( ...
                @SolverIntegrationTest.unconstrainedObjectives, ...
                @SolverIntegrationTest.alwaysInfeasibleConstraint, ...
                X0, Y0, false(4, 1), [0, 0], [1, 1], ...
                SolverIntegrationTest.fastOptions(2, 67));
            states = reshape([result.iterations.selectionState], [], 1);
            sources = reshape([result.iterations.selectionSource], [], 1);
            reasons = reshape([result.iterations.fallbackReason], [], 1);
            labels = result.data.isFeasible;
        end

        function record = unconstrainedRecord()
            X0 = [0, 0; 0, 1; 1, 0; 1, 1];
            Y0 = SolverIntegrationTest.unconstrainedObjectives(X0);
            result = cTSEMO( ...
                @SolverIntegrationTest.unconstrainedObjectives, [], ...
                X0, Y0, [], [0, 0], [1, 1], ...
                SolverIntegrationTest.fastOptions(1, 47));
            record = result.iterations(1);
        end

        function call = autoAmbiguousRuntimeCall()
            X0 = [0, 0; 0, 1; 1, 0; 1, 1];
            Y0 = SolverIntegrationTest.unconstrainedObjectives(X0);
            C0 = [-1; 2; -0.5; 1.5];
            options = SolverIntegrationTest.fastOptions(1, 53);
            call = @() cTSEMO( ...
                @SolverIntegrationTest.unconstrainedObjectives, ...
                @SolverIntegrationTest.numericOneConstraint, ...
                X0, Y0, C0, [0, 0], [1, 1], options);
        end

        function labels = explicitRuntimeLabels()
            labels = [ ...
                SolverIntegrationTest.explicitRuntimeLabel( ...
                    "feasibleIsOne", 1, [1; 0; 1; 0], 59); ...
                SolverIntegrationTest.explicitRuntimeLabel( ...
                    "feasibleIsZero", 0, [0; 1; 0; 1], 61)];
        end

        function [storedHvi, reconstructedHvi, storedAF, ...
                reconstructedAF, storedStandardizedDraw, ...
                reconstructedStandardizedDraw] = ...
                reconstructedAcquisition()
            result = SolverIntegrationTest.tinyCossinRun();
            record = result.iterations(1);
            initialRows = 1:result.data.nInitial;
            trainingY = result.data.Y(initialRows, :);
            trainingLabels = result.data.isFeasible(initialRows);
            center = record.objectiveScaling.center;
            scale = record.objectiveScaling.scale;
            standardizedTrainingY = (trainingY - center) ./ scale;
            feasibleY = standardizedTrainingY(trainingLabels, :);
            reconstructedHvi = ctsemo.sampledHVI( ...
                record.selected.YDrawStandardized, feasibleY, ...
                record.acquisitionReferencePoint);
            reconstructedAF = ...
                (reconstructedHvi + record.acquisitionStatus.epsilon) .* ...
                record.selected.pof .^ ...
                record.acquisitionStatus.pofPower .* ...
                record.selected.designMask .* ...
                record.selected.codomainMask;
            reconstructedStandardizedDraw = ...
                (record.selected.YDraw - center) ./ scale;
            storedHvi = record.selected.sampledHVI;
            storedAF = record.selected.AF;
            storedStandardizedDraw = ...
                record.selected.YDrawStandardized;
        end

        function [primaryCount, challengerCount, searchMethod, ...
                searchStatus, primaryOrigin, returnedSeedBest, ...
                searchBestScore, primaryAF, challengerOrigins] = ...
                finalCandidateCounts()
            result = SolverIntegrationTest.tinyCossinRun();
            record = result.iterations(1);
            primaryCount = record.primary.candidateCount;
            challengerCount = record.challenger.candidateCount;
            searchMethod = record.primarySearch.method;
            searchStatus = record.primarySearch.status;
            primaryOrigin = record.candidates.origin( ...
                record.candidates.source == "primary");
            returnedSeedBest = record.primarySearch.returnedSeedBest;
            searchBestScore = record.primarySearch.bestScore;
            primaryAF = record.primary.AF;
            challengerOrigins = record.candidates.origin( ...
                record.candidates.source == "challenger");
        end

        function [status, seedBestScore, bestScore, improvement, ...
                returnedSeedBest] = poolModeDiagnostics()
            problem = getBenchmarkProblem("COSSIN1");
            X0 = initialDesign(problem, 8, 13);
            Y0 = problem.objective(X0);
            C0 = problem.feasible(X0);
            options = SolverIntegrationTest.fastOptions(1, 97);
            options.primarySearch.method = "pool";
            result = cTSEMO( ...
                problem.objective, problem.feasible, X0, Y0, C0, ...
                problem.lowerBound, problem.upperBound, options);
            diagnostics = result.iterations(1).primarySearch;
            status = diagnostics.status;
            seedBestScore = diagnostics.seedBestScore;
            bestScore = diagnostics.bestScore;
            improvement = diagnostics.improvementOverSeed;
            returnedSeedBest = diagnostics.returnedSeedBest;
        end

        function [storedMaximum, selectedAF, selectedSource, ...
                sourceAtMaximum, fallbackUsed] = completePoolMaximum()
            result = SolverIntegrationTest.tinyCossinRun();
            record = result.iterations(1);
            [storedMaximum, index] = max(record.candidates.AF);
            selectedAF = record.selected.AF;
            selectedSource = record.selected.candidateSource;
            sourceAtMaximum = record.candidates.source(index);
            fallbackUsed = record.fallbackUsed;
        end

        function [status, dimension, evaluationCount, labelsAgree] = ...
                tenDimensionalCf1Evidence()
            problem = getBenchmarkProblem("CF1_D10");
            X0 = initialDesign(problem, 20, 83, ...
                struct("IncludeCorners", false));
            Y0 = problem.objective(X0);
            C0 = problem.label01(X0);
            options = SolverIntegrationTest.fastOptions(1, 89);
            options.candidates.includeCorners = false;
            options.feasibility.inputEncoding = "feasibleIsOne";
            result = cTSEMO( ...
                problem.objective, problem.label01, ...
                X0, Y0, C0, ...
                problem.lowerBound, problem.upperBound, options);
            status = result.meta.status;
            dimension = size(result.data.X, 2);
            evaluationCount = size(result.data.X, 1);
            labelsAgree = isequal( ...
                logical(result.data.isFeasible), ...
                logical(problem.feasible(result.data.X)));
        end

        function label = explicitRuntimeLabel( ...
                encoding, constraintValue, C0, seed)
            X0 = [0, 0; 0, 1; 1, 0; 1, 1];
            Y0 = SolverIntegrationTest.unconstrainedObjectives(X0);
            options = SolverIntegrationTest.fastOptions(1, seed);
            options.feasibility.inputEncoding = encoding;
            constraint = @(X) repmat( ...
                constraintValue, size(X, 1), 1);
            result = cTSEMO( ...
                @SolverIntegrationTest.unconstrainedObjectives, ...
                constraint, X0, Y0, C0, ...
                [0, 0], [1, 1], options);
            label = result.data.isFeasible(end);
        end

        function value = numericOneConstraint(X)
            value = ones(size(X, 1), 1);
        end

        function value = alwaysInfeasibleConstraint(X)
            value = false(size(X, 1), 1);
        end

        function Y = unconstrainedObjectives(X)
            Y = [sum(X.^2, 2), sum((X - 1).^2, 2)];
        end

        function options = fastOptions(evaluationCount, seed)
            options = cTSEMOOptions(struct( ...
                "maxEvaluations", evaluationCount, ...
                "seed", seed, ...
                "candidates", struct( ...
                    "primaryCount", 48, ...
                    "includeCorners", true), ...
                "primarySearch", struct( ...
                    "populationSize", 12, ...
                    "eliteCount", 1, ...
                    "maxGenerations", 4, ...
                    "maxStallGenerations", 2, ...
                    "functionTolerance", 1.0e-8, ...
                    "useParallel", false), ...
                "objectiveGP", struct("nFeatures", 48), ...
                "masks", struct( ...
                    "design", struct("enabled", false), ...
                    "codomain", struct("enabled", false)), ...
                "challengers", struct( ...
                    "enabled", true, ...
                    "count", 24), ...
                "logging", struct( ...
                    "level", "full", ...
                    "checkpoint", false, ...
                    "saveEveryIteration", false)));
        end
    end
end
