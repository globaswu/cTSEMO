classdef BinaryAndOptionsTest < matlab.unittest.TestCase
    %BinaryAndOptionsTest Binary-label, option, and input-contract tests.

    methods (TestClassSetup)
        function addReleasePaths(testCase)
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                releaseRoot));
        end
    end

    methods (Test, TestTags = {'Unit'})
        function testBinaryLabelsRejectNonfiniteRows(testCase)
            [actual, diagnostics] = ...
                BinaryAndOptionsTest.labelsWithNonfiniteRows();

            testCase.verifyEqual(actual, ...
                logical([1; 0; 0; 0; 0]));
            testCase.verifyEqual(diagnostics.nonfiniteRowCount, 3);
            testCase.verifyEqual(diagnostics.feasibleCount, 1);
        end

        function testBinaryLabelsUseTolerance(testCase)
            actual = BinaryAndOptionsTest.labelsAtTolerance();

            testCase.verifyEqual(actual, logical([1; 0]));
        end

        function testReleaseRawTargets(testCase)
            options = cTSEMOOptions();

            testCase.verifyEqual(options.pof.rawInfeasible, -0.25, ...
                AbsTol=eps);
            testCase.verifyEqual(options.pof.rawFeasible, 1.25, ...
                AbsTol=eps);
            testCase.verifyEqual(options.pof.clipBounds, [0, 1], ...
                AbsTol=eps);
        end

        function testAdjustableRawTargets(testCase)
            options = BinaryAndOptionsTest.adjustedTargetOptions();

            testCase.verifyEqual(options.pof.rawInfeasible, -0.1, ...
                AbsTol=eps);
            testCase.verifyEqual(options.pof.rawFeasible, 1.1, ...
                AbsTol=eps);
        end

        function testPoFBoundaryValuesAreAccepted(testCase)
            values = BinaryAndOptionsTest.acceptedPoFBoundaryValues();

            testCase.verifyEqual(values, [0, 1, 0, 1.0e-4], ...
                AbsTol=eps);
        end

        function testPositiveRawInfeasibleIsRejected(testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.positiveRawInfeasibleCall(), ...
                "cTSEMO:Options:InvalidPoFTargets");
        end

        function testSubunitRawFeasibleIsRejected(testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.subunitRawFeasibleCall(), ...
                "cTSEMO:Options:InvalidPoFTargets");
        end

        function testPriorAtInfeasibleTargetIsRejected(testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.priorAtInfeasibleTargetCall(), ...
                "cTSEMO:Options:InvalidPoFPrior");
        end

        function testPriorAtFeasibleTargetIsRejected(testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.priorAtFeasibleTargetCall(), ...
                "cTSEMO:Options:InvalidPoFPrior");
        end

        function testExcessivePoFJitterIsRejected(testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.excessivePoFJitterCall(), ...
                "cTSEMO:Options:InvalidPoFJitter");
        end

        function testNoOpFieldsAreAbsentFromSchema(testCase)
            isAbsent = BinaryAndOptionsTest.noOpFieldsAreAbsent();

            testCase.verifyTrue(all(isAbsent));
        end

        function testCompletePoolScoringIsShippedDefault(testCase)
            options = cTSEMOOptions();

            testCase.verifyTrue( ...
                options.challengers.scoreCompletePools);
        end

        function testLegacyChallengerAblationCanBeRequested(testCase)
            options = cTSEMOOptions(struct( ...
                "challengers", struct( ...
                    "scoreCompletePools", false)));

            testCase.verifyFalse( ...
                options.challengers.scoreCompletePools);
        end

        function testCompletePoolScoringRequiresLogicalScalar(testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.numericCompletePoolFlagCall(), ...
                "cTSEMO:Options:ExpectedLogicalScalar");
        end

        function testUnknownTopLevelOptionIsRejected(testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.unknownTopLevelOptionCall(), ...
                "cTSEMO:Options:UnknownField");
        end

        function testUnknownNestedOptionIsRejected(testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.unknownNestedOptionCall(), ...
                "cTSEMO:Options:UnknownField");
        end

        function testExplicitFeasibleIsOneEncoding(testCase)
            labels = BinaryAndOptionsTest.validatedOneEncoding();

            testCase.verifyEqual(labels, logical([1; 0; 1]));
        end

        function testContinuousEncodingTreatsNonfiniteAsInfeasible(testCase)
            labels = BinaryAndOptionsTest.validatedContinuousEncoding();

            testCase.verifyEqual(labels, logical([1; 0; 0]));
        end

        function testAmbiguousNumericLabelsAreRejected(testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.ambiguousLabelCall(), ...
                "cTSEMO:Inputs:AmbiguousNumericLabels");
        end

        function testDuplicateLocationsWithConflictingLabelsAreRejected( ...
                testCase)
            testCase.verifyError( ...
                BinaryAndOptionsTest.conflictingDuplicateInputCall(), ...
                "cTSEMO:Inputs:ConflictingDuplicateLabels");
        end

        function testAllFeasibleStateIsClassified(testCase)
            state = BinaryAndOptionsTest.allFeasibleState();

            testCase.verifyEqual(state, "allFeasible");
        end

        function testNoFeasibleStateIsClassified(testCase)
            state = BinaryAndOptionsTest.noFeasibleState();

            testCase.verifyEqual(state, "noneFeasible");
        end
    end

    methods (Static, Access = private)
        function [labels, diagnostics] = labelsWithNonfiniteRows()
            margins = [-1, 0; 0.1, -1; NaN, -1; -Inf, -1; -1, Inf];
            [labels, diagnostics] = ctsemo.binaryLabels(margins);
        end

        function labels = labelsAtTolerance()
            margins = [1.0e-5, -1; 2.0e-5, -1];
            labels = ctsemo.binaryLabels(margins, 1.0e-5);
        end

        function options = adjustedTargetOptions()
            options = cTSEMOOptions(struct( ...
                "pof", struct( ...
                    "rawInfeasible", -0.1, ...
                    "rawFeasible", 1.1)));
        end

        function values = acceptedPoFBoundaryValues()
            zeroJitter = cTSEMOOptions(struct( ...
                "pof", struct( ...
                    "rawInfeasible", 0, ...
                    "rawFeasible", 1, ...
                    "priorMean", 0.5, ...
                    "jitter", 0)));
            maximumJitter = cTSEMOOptions(struct( ...
                "pof", struct("jitter", 1.0e-4)));
            values = [ ...
                zeroJitter.pof.rawInfeasible, ...
                zeroJitter.pof.rawFeasible, ...
                zeroJitter.pof.jitter, ...
                maximumJitter.pof.jitter];
        end

        function call = positiveRawInfeasibleCall()
            call = @() cTSEMOOptions(struct( ...
                "pof", struct("rawInfeasible", eps)));
        end

        function call = subunitRawFeasibleCall()
            call = @() cTSEMOOptions(struct( ...
                "pof", struct("rawFeasible", 1 - eps)));
        end

        function call = priorAtInfeasibleTargetCall()
            call = @() cTSEMOOptions(struct( ...
                "pof", struct( ...
                    "rawInfeasible", 0, ...
                    "priorMean", 0)));
        end

        function call = priorAtFeasibleTargetCall()
            call = @() cTSEMOOptions(struct( ...
                "pof", struct( ...
                    "rawFeasible", 1, ...
                    "priorMean", 1)));
        end

        function call = excessivePoFJitterCall()
            call = @() cTSEMOOptions(struct( ...
                "pof", struct("jitter", 1.0e-4 + eps)));
        end

        function isAbsent = noOpFieldsAreAbsent()
            options = cTSEMOOptions();
            isAbsent = [ ...
                ~isfield(options.challengers, "refineCount"), ...
                ~isfield(options.fallback, "pofSoftness"), ...
                ~isfield(options.fallback, "pofPower"), ...
                ~isfield(options.fallback, "noFeasiblePolicy"), ...
                ~isfield(options.fallback, "allFeasiblePolicy")];
        end

        function call = unknownTopLevelOptionCall()
            call = @() cTSEMOOptions(struct("misspelledOption", 1));
        end

        function call = numericCompletePoolFlagCall()
            call = @() cTSEMOOptions(struct( ...
                "challengers", struct( ...
                    "scoreCompletePools", 1)));
        end

        function call = unknownNestedOptionCall()
            call = @() cTSEMOOptions(struct( ...
                "pof", struct("misspelledOption", 1)));
        end

        function labels = validatedOneEncoding()
            X = [0, 0; 0.5, 0.5; 1, 1];
            Y = BinaryAndOptionsTest.objectives(X);
            C = [1; 0; 1];
            options = cTSEMOOptions(struct( ...
                "feasibility", struct("inputEncoding", "feasibleIsOne")));
            [~, data] = ctsemo.validateInputs( ...
                @BinaryAndOptionsTest.objectives, ...
                @BinaryAndOptionsTest.logicalConstraint, ...
                X, Y, C, [0, 0], [1, 1], options);
            labels = data.isFeasible;
        end

        function labels = validatedContinuousEncoding()
            X = [0, 0; 0.5, 0.5; 1, 1];
            Y = BinaryAndOptionsTest.objectives(X);
            C = [-1; 0.1; NaN];
            options = cTSEMOOptions(struct( ...
                "feasibility", struct( ...
                    "inputEncoding", "continuousInequality")));
            [~, data] = ctsemo.validateInputs( ...
                @BinaryAndOptionsTest.objectives, ...
                @BinaryAndOptionsTest.logicalConstraint, ...
                X, Y, C, [0, 0], [1, 1], options);
            labels = data.isFeasible;
        end

        function call = ambiguousLabelCall()
            X = [0, 0; 1, 1];
            Y = BinaryAndOptionsTest.objectives(X);
            call = @() ctsemo.validateInputs( ...
                @BinaryAndOptionsTest.objectives, ...
                @BinaryAndOptionsTest.logicalConstraint, ...
                X, Y, [0; 1], [0, 0], [1, 1], cTSEMOOptions());
        end

        function call = conflictingDuplicateInputCall()
            X = [0.25, 0.75; 0.25, 0.75];
            Y = BinaryAndOptionsTest.objectives(X);
            options = cTSEMOOptions(struct( ...
                "feasibility", struct("inputEncoding", "feasibleIsOne")));
            call = @() ctsemo.validateInputs( ...
                @BinaryAndOptionsTest.objectives, ...
                @BinaryAndOptionsTest.logicalConstraint, ...
                X, Y, [1; 0], [0, 0], [1, 1], options);
        end

        function state = allFeasibleState()
            state = BinaryAndOptionsTest.validationState(logical([1; 1]));
        end

        function state = noFeasibleState()
            state = BinaryAndOptionsTest.validationState(logical([0; 0]));
        end

        function state = validationState(labels)
            X = [0, 0; 1, 1];
            Y = BinaryAndOptionsTest.objectives(X);
            [~, data] = ctsemo.validateInputs( ...
                @BinaryAndOptionsTest.objectives, ...
                @BinaryAndOptionsTest.logicalConstraint, ...
                X, Y, labels, [0, 0], [1, 1], cTSEMOOptions());
            state = data.feasibilityState;
        end

        function values = objectives(X)
            values = [sum(X.^2, 2), sum((X - 1).^2, 2)];
        end

        function labels = logicalConstraint(X)
            labels = sum(X, 2) <= 1;
        end
    end
end
