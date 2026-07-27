classdef ClippedBinaryPofTest < matlab.unittest.TestCase
    %ClippedBinaryPofTest Tests for the clipped local binary-GP mean.

    methods (TestClassSetup)
        function addReleasePath(testCase)
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                releaseRoot));
        end
    end

    methods (Test, TestTags = {'Unit', 'PoF'})
        function testDefaultRawTargetsAndExactAnchors(testCase)
            [rawTargets, pof, rawMean, labels] = ...
                ClippedBinaryPofTest.defaultAnchorPrediction();

            testCase.verifyEqual(rawTargets, [-0.25; 1.25; -0.25; 1.25], ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(rawMean, rawTargets, AbsTol=1.0e-12);
            testCase.verifyEqual(pof, double(labels), AbsTol=1.0e-12);
        end

        function testOptionsRawTargetsReachInterpolator(testCase)
            [rawTargets, pof, rawMean] = ...
                ClippedBinaryPofTest.adjustableTargetPrediction();

            testCase.verifyEqual(rawTargets, [-0.1; 1.1; -0.1; 1.1], ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(rawMean, rawTargets, AbsTol=1.0e-12);
            testCase.verifyEqual(pof, [0; 1; 0; 1], AbsTol=1.0e-12);
        end

        function testPredictionsAreClippedToUnitInterval(testCase)
            pof = ClippedBinaryPofTest.gridPrediction();

            testCase.verifyGreaterThanOrEqual(pof, zeros(size(pof)));
            testCase.verifyLessThanOrEqual(pof, ones(size(pof)));
        end

        function testConsistentDuplicatesAreConsolidated(testCase)
            diagnostics = ClippedBinaryPofTest.consistentDuplicateFit();

            testCase.verifyEqual(diagnostics.observationCount, 4);
            testCase.verifyEqual(diagnostics.uniqueObservationCount, 3);
            testCase.verifyEqual(diagnostics.consolidatedDuplicateCount, 1);
        end

        function testConflictingDuplicatesAreRejected(testCase)
            testCase.verifyError( ...
                ClippedBinaryPofTest.conflictingDuplicateCall(), ...
                "ctsemo:fitClippedBinaryPof:ConflictingDuplicateLabels");
        end

        function testAllFeasibleAnchors(testCase)
            [pof, rawMean] = ClippedBinaryPofTest.allFeasibleFit();

            testCase.verifyEqual(pof, ones(size(pof)), AbsTol=1.0e-12);
            testCase.verifyEqual(rawMean, 1.25 .* ones(size(rawMean)), ...
                AbsTol=1.0e-12);
        end

        function testAllInfeasibleAnchors(testCase)
            [pof, rawMean] = ClippedBinaryPofTest.allInfeasibleFit();

            testCase.verifyEqual(pof, zeros(size(pof)), AbsTol=1.0e-12);
            testCase.verifyEqual(rawMean, -0.25 .* ones(size(rawMean)), ...
                AbsTol=1.0e-12);
        end

        function testFourDimensionalExactInterpolation(testCase)
            [pof, rawMean, expectedRaw] = ...
                ClippedBinaryPofTest.fourDimensionalFit();

            testCase.verifyEqual(pof, [0; 1; 0; 1; 1], ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(rawMean, expectedRaw, ...
                AbsTol=1.0e-12);
        end

        function testSixDimensionalExactInterpolation(testCase)
            [pof, rawMean, expectedRaw] = ...
                ClippedBinaryPofTest.sixDimensionalFit();

            testCase.verifyEqual(pof, [0; 1; 0; 1; 1; 0], ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(rawMean, expectedRaw, ...
                AbsTol=1.0e-12);
        end

        function testStationaryFallbackHasConstantLength(testCase)
            trainingLength = ...
                ClippedBinaryPofTest.stationaryTrainingLength();

            testCase.verifyEqual(trainingLength, ...
                trainingLength(1) .* ones(size(trainingLength)), ...
                AbsTol=1.0e-12);
        end

        function testDenseInfeasibleRegionGetsLongerLocalLength(testCase)
            [denseLength, sparseLength] = ...
                ClippedBinaryPofTest.denseAndSparseLengths();

            testCase.verifyGreaterThan(denseLength, sparseLength);
        end
    end

    methods (Static, Access = private)
        function [rawTargets, pof, rawMean, labels] = ...
                defaultAnchorPrediction()
            [X, labels] = ClippedBinaryPofTest.mixedData2D();
            model = ctsemo.fitClippedBinaryPof(X, labels);
            [pof, rawMean] = ctsemo.predictClippedBinaryPof(model, X);
            rawTargets = model.rawTargets(model.groupIndex);
        end

        function [rawTargets, pof, rawMean] = ...
                adjustableTargetPrediction()
            [X, labels] = ClippedBinaryPofTest.mixedData2D();
            options = cTSEMOOptions(struct( ...
                "pof", struct( ...
                    "rawInfeasible", -0.1, ...
                    "rawFeasible", 1.1)));
            model = ctsemo.fitClippedBinaryPof(X, labels, options);
            [pof, rawMean] = ctsemo.predictClippedBinaryPof(model, X);
            rawTargets = model.rawTargets(model.groupIndex);
        end

        function pof = gridPrediction()
            [X, labels] = ClippedBinaryPofTest.mixedData2D();
            model = ctsemo.fitClippedBinaryPof(X, labels);
            axisValues = linspace(0, 1, 21);
            [x1, x2] = ndgrid(axisValues, axisValues);
            pof = ctsemo.predictClippedBinaryPof( ...
                model, [x1(:), x2(:)]);
        end

        function diagnostics = consistentDuplicateFit()
            X = [0, 0; 0.25, 0.75; 0.25, 0.75; 1, 1];
            labels = logical([0; 1; 1; 0]);
            [~, diagnostics] = ctsemo.fitClippedBinaryPof(X, labels);
        end

        function call = conflictingDuplicateCall()
            X = [0, 0; 0.25, 0.75; 0.25, 0.75; 1, 1];
            labels = logical([0; 1; 0; 0]);
            call = @() ctsemo.fitClippedBinaryPof(X, labels);
        end

        function [pof, rawMean] = allFeasibleFit()
            X = [0, 0; 0, 1; 1, 0; 1, 1];
            labels = true(4, 1);
            model = ctsemo.fitClippedBinaryPof(X, labels);
            [pof, rawMean] = ctsemo.predictClippedBinaryPof(model, X);
        end

        function [pof, rawMean] = allInfeasibleFit()
            X = [0, 0; 0, 1; 1, 0; 1, 1];
            labels = false(4, 1);
            model = ctsemo.fitClippedBinaryPof(X, labels);
            [pof, rawMean] = ctsemo.predictClippedBinaryPof(model, X);
        end

        function [pof, rawMean, expectedRaw] = fourDimensionalFit()
            X = [ ...
                0.0, 0.0, 0.0, 0.0; ...
                1.0, 0.0, 1.0, 0.0; ...
                0.0, 1.0, 0.0, 1.0; ...
                1.0, 1.0, 1.0, 1.0; ...
                0.5, 0.5, 0.5, 0.5];
            labels = logical([0; 1; 0; 1; 1]);
            model = ctsemo.fitClippedBinaryPof(X, labels);
            [pof, rawMean] = ctsemo.predictClippedBinaryPof(model, X);
            expectedRaw = -0.25 + 1.5 .* double(labels);
        end

        function [pof, rawMean, expectedRaw] = sixDimensionalFit()
            X = [ ...
                zeros(1, 6); ...
                ones(1, 6); ...
                0, 1, 0, 1, 0, 1; ...
                1, 0, 1, 0, 1, 0; ...
                repmat(0.5, 1, 6); ...
                0.2, 0.4, 0.6, 0.8, 0.3, 0.7];
            labels = logical([0; 1; 0; 1; 1; 0]);
            model = ctsemo.fitClippedBinaryPof(X, labels);
            [pof, rawMean] = ...
                ctsemo.predictClippedBinaryPof(model, X);
            expectedRaw = -0.25 + 1.5 .* double(labels);
        end

        function trainingLength = stationaryTrainingLength()
            X = [0.1, 0.1; 0.11, 0.1; 0.1, 0.11; 0.8, 0.8];
            labels = false(4, 1);
            model = ctsemo.fitClippedBinaryPof( ...
                X, labels, struct("localStrength", 0));
            trainingLength = model.trainingLength;
        end

        function [denseLength, sparseLength] = denseAndSparseLengths()
            X = [0.1, 0.1; 0.11, 0.1; 0.1, 0.11; 0.8, 0.8];
            labels = false(4, 1);
            model = ctsemo.fitClippedBinaryPof( ...
                X, labels, struct( ...
                    "baseLength", 0.15, ...
                    "densityBandwidth", 0.05, ...
                    "localStrength", 2));
            denseLength = mean(model.trainingLength(1:3));
            sparseLength = model.trainingLength(4);
        end

        function [X, labels] = mixedData2D()
            X = [0, 0; 0, 1; 1, 0; 1, 1];
            labels = logical([0; 1; 0; 1]);
        end
    end
end
