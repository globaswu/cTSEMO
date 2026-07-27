classdef CandidateAndParetoTest < matlab.unittest.TestCase
    %CandidateAndParetoTest Candidate-pool and Pareto/HV contract tests.

    methods (TestClassSetup)
        function addReleasePath(testCase)
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                releaseRoot));
        end
    end

    methods (Test, TestTags = {'Unit', 'Acquisition'})
        function testCandidatePoolsAreDeterministic(testCase)
            [firstPool, secondPool] = ...
                CandidateAndParetoTest.repeatedPools();

            testCase.verifyEqual(firstPool.primary.X, ...
                secondPool.primary.X, AbsTol=1.0e-14);
            testCase.verifyEqual(firstPool.challenger.X, ...
                secondPool.challenger.X, AbsTol=1.0e-14);
        end

        function testCandidatePoolRestoresCallerRng(testCase)
            [before, after] = CandidateAndParetoTest.rngAroundPool();

            testCase.verifyEqual(after, before);
        end

        function testCandidatePoolsExcludeEvaluatedPoints(testCase)
            minimumDistance = ...
                CandidateAndParetoTest.minimumCandidateDistance();

            testCase.verifyGreaterThan(minimumDistance, 1.0e-9);
        end

        function testPrimaryAndChallengerPoolsAreDisjoint(testCase)
            overlapCount = CandidateAndParetoTest.poolOverlapCount();

            testCase.verifyEqual(overlapCount, 0);
        end

        function testTwoDimensionalPrimaryPoolIncludesCorners(testCase)
            cornerCount = CandidateAndParetoTest.primaryCornerCount();

            testCase.verifyEqual(cornerCount, 4);
        end

        function testParetoFrontAndHypervolume(testCase)
            pareto = CandidateAndParetoTest.knownParetoFront();

            testCase.verifyEqual(pareto.Y, [1, 4; 2, 2; 4, 1], ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(pareto.hypervolume, 11, ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(pareto.nPoints, 3);
        end

        function testInfeasiblePointsDoNotEnterParetoFront(testCase)
            pareto = CandidateAndParetoTest.knownParetoFront();

            testCase.verifyFalse(any(pareto.index == 5));
        end

        function testNoFeasiblePointGivesEmptyParetoFront(testCase)
            pareto = CandidateAndParetoTest.emptyParetoFront();

            testCase.verifyEmpty(pareto.X);
            testCase.verifyEmpty(pareto.Y);
            testCase.verifyEqual(pareto.hypervolume, 0, AbsTol=eps);
        end
    end

    methods (Static, Access = private)
        function [firstPool, secondPool] = repeatedPools()
            options = CandidateAndParetoTest.smallPoolOptions();
            evaluatedX = [0, 0; 1, 1; 0.5, 0.5];
            firstPool = ctsemo.makeCandidatePools( ...
                [0, 0], [1, 1], options, 4, evaluatedX);
            secondPool = ctsemo.makeCandidatePools( ...
                [0, 0], [1, 1], options, 4, evaluatedX);
        end

        function [before, after] = rngAroundPool()
            rng(610, "twister");
            before = rng;
            options = CandidateAndParetoTest.smallPoolOptions();
            ctsemo.makeCandidatePools( ...
                [0, 0], [1, 1], options, 2, [0.5, 0.5]);
            after = rng;
        end

        function distance = minimumCandidateDistance()
            evaluatedX = [0, 0; 1, 1; 0.5, 0.5];
            options = CandidateAndParetoTest.smallPoolOptions();
            pools = ctsemo.makeCandidatePools( ...
                [0, 0], [1, 1], options, 4, evaluatedX);
            squaredDistance = sum(pools.X.^2, 2) + ...
                sum(evaluatedX.^2, 2)' - 2 .* (pools.X * evaluatedX');
            distance = sqrt(min(max(0, squaredDistance), [], "all"));
        end

        function count = poolOverlapCount()
            [firstPool, ~] = CandidateAndParetoTest.repeatedPools();
            count = nnz(ismember( ...
                firstPool.challenger.X, firstPool.primary.X, "rows"));
        end

        function count = primaryCornerCount()
            options = CandidateAndParetoTest.smallPoolOptions();
            pools = ctsemo.makeCandidatePools( ...
                [0, 0], [1, 1], options, 1, [0.5, 0.5]);
            count = nnz(pools.primary.origin == "corner");
        end

        function pareto = knownParetoFront()
            X = (1:5)';
            Y = [1, 4; 2, 2; 4, 1; 3, 3; 0, 0];
            isFeasible = logical([1; 1; 1; 1; 0]);
            pareto = ctsemo.updatePareto( ...
                X, Y, isFeasible, [5, 5]);
        end

        function pareto = emptyParetoFront()
            X = [0, 0; 1, 1];
            Y = [1, 2; 2, 1];
            pareto = ctsemo.updatePareto( ...
                X, Y, false(2, 1), [3, 3]);
        end

        function options = smallPoolOptions()
            options = cTSEMOOptions(struct( ...
                "seed", 123, ...
                "candidates", struct( ...
                    "primaryCount", 24, ...
                    "includeCorners", true), ...
                "challengers", struct( ...
                    "enabled", true, ...
                    "count", 16)));
        end
    end
end
