classdef PrimaryGaTest < matlab.unittest.TestCase
    %PrimaryGaTest Deterministic primary-acquisition GA tests.

    methods (TestClassSetup)
        function addReleasePath(testCase)
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                releaseRoot));
        end
    end

    methods (Test, TestTags = {'Unit', 'Acquisition', 'GA'})
        function testGaDoesNotUnderperformItsSeedPool(testCase)
            [bestScore, seedBestScore, xBest] = ...
                PrimaryGaTest.optimizedQuadratic();

            testCase.verifyGreaterThanOrEqual(bestScore, ...
                seedBestScore - 1.0e-12);
            testCase.verifyGreaterThanOrEqual(xBest, zeros(1, 2));
            testCase.verifyLessThanOrEqual(xBest, ones(1, 2));
        end

        function testGaReportsCompletedSearch(testCase)
            [~, ~, ~, diagnostics] = ...
                PrimaryGaTest.optimizedQuadratic();

            testCase.verifyEqual(diagnostics.method, "ga");
            testCase.verifyEqual(diagnostics.status, "completed");
            testCase.verifyGreaterThan(diagnostics.functionCount, 0);
            testCase.verifyEqual(diagnostics.seedCandidateCount, 12);
        end

        function testGaIsDeterministic(testCase)
            [scoreA, ~, xA] = PrimaryGaTest.optimizedQuadratic();
            [scoreB, ~, xB] = PrimaryGaTest.optimizedQuadratic();

            testCase.verifyEqual(xA, xB, AbsTol=1.0e-12);
            testCase.verifyEqual(scoreA, scoreB, AbsTol=1.0e-12);
        end

        function testGaRestoresCallerRandomStream(testCase)
            rng(9127, "twister");
            before = rng;
            PrimaryGaTest.optimizedQuadratic();
            after = rng;

            testCase.verifyEqual(after, before);
        end

        function testExplicitPoolAblationReturnsSeedMaximum(testCase)
            [xBest, bestScore, expectedX, expectedScore, status] = ...
                PrimaryGaTest.poolAblation();

            testCase.verifyEqual(xBest, expectedX, AbsTol=eps);
            testCase.verifyEqual(bestScore, expectedScore, AbsTol=eps);
            testCase.verifyEqual(status, "pool");
        end
    end

    methods (Static, Access = private)
        function [bestScore, seedBestScore, xBest, diagnostics] = ...
                optimizedQuadratic()
            [seedPoints, scoreFunction] = PrimaryGaTest.fixture();
            seedScores = scoreFunction(seedPoints);
            options = PrimaryGaTest.fastGaOptions("ga");
            [xBest, bestScore, diagnostics] = ...
                ctsemo.optimizePrimaryGA( ...
                scoreFunction, seedPoints, seedScores, options, 3);
            seedBestScore = max(seedScores);
        end

        function [xBest, bestScore, expectedX, expectedScore, status] = ...
                poolAblation()
            [seedPoints, scoreFunction] = PrimaryGaTest.fixture();
            seedScores = scoreFunction(seedPoints);
            options = PrimaryGaTest.fastGaOptions("pool");
            [xBest, bestScore, diagnostics] = ...
                ctsemo.optimizePrimaryGA( ...
                scoreFunction, seedPoints, seedScores, options, 3);
            [expectedScore, index] = max(seedScores);
            expectedX = seedPoints(index, :);
            status = diagnostics.status;
        end

        function [seedPoints, scoreFunction] = fixture()
            seedPoints = [ ...
                0.05, 0.05; 0.90, 0.90; 0.20, 0.70; 0.70, 0.20; ...
                0.40, 0.40; 0.10, 0.90; 0.90, 0.10; 0.30, 0.60; ...
                0.60, 0.30; 0.80, 0.50; 0.50, 0.80; 0.20, 0.20];
            target = [0.35, 0.65];
            scoreFunction = @(X) max(0, ...
                1 - sum((X - target).^2, 2));
        end

        function options = fastGaOptions(method)
            options = cTSEMOOptions(struct( ...
                "seed", 17, ...
                "primarySearch", struct( ...
                    "method", method, ...
                    "populationSize", 12, ...
                    "eliteCount", 1, ...
                    "maxGenerations", 4, ...
                    "maxStallGenerations", 2, ...
                    "functionTolerance", 1.0e-8, ...
                    "useParallel", false)));
        end
    end
end
