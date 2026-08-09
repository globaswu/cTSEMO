classdef AcquisitionAndFallbackTest < matlab.unittest.TestCase
    %AcquisitionAndFallbackTest Sampled-HVI, mask, AF, and recovery tests.

    methods (TestClassSetup)
        function addReleasePath(testCase)
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                releaseRoot));
        end
    end

    methods (Test, TestTags = {'Unit', 'Acquisition'})
        function testPareto2dRemovesDominatedAndDuplicateRows(testCase)
            [front, indices] = ...
                AcquisitionAndFallbackTest.knownPareto2d();

            testCase.verifyEqual(front, [1, 4; 2, 2; 4, 1], ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(indices, [1; 2; 3]);
        end

        function testHypervolume2dKnownUnion(testCase)
            hypervolume = ...
                AcquisitionAndFallbackTest.knownHypervolume();

            testCase.verifyEqual(hypervolume, 11, ...
                AbsTol=1.0e-12);
        end

        function testSampledHviKnownImprovement(testCase)
            [hvi, requiresFallback] = ...
                AcquisitionAndFallbackTest.knownSampledHvi();

            testCase.verifyEqual(hvi, [2.25; 0; 0], ...
                AbsTol=1.0e-12);
            testCase.verifyFalse(requiresFallback);
        end

        function testNoPositiveSampledHviRequestsFallback(testCase)
            [hvi, reason, requiresFallback] = ...
                AcquisitionAndFallbackTest.zeroSampledHvi();

            testCase.verifyEqual(hvi, zeros(2, 1), AbsTol=eps);
            testCase.verifyEqual(reason, "no_positive_hvi");
            testCase.verifyTrue(requiresFallback);
        end

        function testFixedEpsilonScoresZeroHviBatchButRequestsFallback( ...
                testCase)
            [score, epsilon, reason, requiresFallback] = ...
                AcquisitionAndFallbackTest.fixedEpsilonZeroHvi();

            testCase.verifyEqual(score, [0.1; 0.16], ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(epsilon, 0.2, AbsTol=eps);
            testCase.verifyEqual(reason, "no_positive_hvi");
            testCase.verifyTrue(requiresFallback);
        end

        function testDisabledSoftMasksReturnOnes(testCase)
            [designMask, codomainMask] = ...
                AcquisitionAndFallbackTest.disabledMaskValues();

            testCase.verifyEqual(designMask, ones(2, 1), ...
                AbsTol=eps);
            testCase.verifyEqual(codomainMask, ones(2, 1), ...
                AbsTol=eps);
        end

        function testHardDesignDuplicateIsAlwaysMasked(testCase)
            [designMask, hardDuplicate] = ...
                AcquisitionAndFallbackTest.hardDuplicateMask();

            testCase.verifyEqual(designMask(1), 0, AbsTol=eps);
            testCase.verifyTrue(hardDuplicate(1));
            testCase.verifyFalse(hardDuplicate(2));
        end

        function testSoftMasksPenalizeNearerCandidates(testCase)
            [designMask, codomainMask] = ...
                AcquisitionAndFallbackTest.nearAndFarMasks();

            testCase.verifyLessThan(designMask(1), designMask(2));
            testCase.verifyLessThan(codomainMask(1), codomainMask(2));
        end

        function testAcquisitionFactorization(testCase)
            [score, expected, components] = ...
                AcquisitionAndFallbackTest.factoredAcquisition();

            testCase.verifyEqual(score, expected, AbsTol=1.0e-12);
            testCase.verifyEqual(components.designMask, ones(2, 1), ...
                AbsTol=eps);
            testCase.verifyEqual(components.codomainMask, ones(2, 1), ...
                AbsTol=eps);
        end

        function testNonunitPofPowerAndDefaultBackground(testCase)
            [score, expectedScore, epsilon, expectedEpsilon, pofPower] = ...
                AcquisitionAndFallbackTest.poweredBackgroundAcquisition();

            testCase.verifyEqual(pofPower, 2, AbsTol=eps);
            testCase.verifyEqual(epsilon, expectedEpsilon, ...
                AbsTol=1.0e-12);
            testCase.verifyEqual(score, expectedScore, ...
                AbsTol=1.0e-12);
        end

        function testDuplicateCandidateHasZeroAcquisition(testCase)
            [score, hardDuplicate] = ...
                AcquisitionAndFallbackTest.duplicateCandidateScore();

            testCase.verifyEqual(score(1), 0, AbsTol=eps);
            testCase.verifyTrue(hardDuplicate(1));
            testCase.verifyGreaterThan(score(2), 0);
        end

        function testPrimaryAndChallengerUseSameAcquisition(testCase)
            [selectedSource, scores] = ...
                AcquisitionAndFallbackTest.sameAcquisitionArbitration();

            testCase.verifyEqual(selectedSource, "challenger");
            testCase.verifyGreaterThan(scores(2), scores(1));
        end

        function testAllInfeasiblePhaseUsesMaximinRecovery(testCase)
            [index, phase, policy] = ...
                AcquisitionAndFallbackTest.maximinRecovery();

            testCase.verifyEqual(index, 3);
            testCase.verifyEqual(phase, "phase_i");
            testCase.verifyEqual(policy, ...
                "maximin_feasibility_novelty");
        end

        function testZeroHviFallbackUsesPofAndNovelty(testCase)
            index = AcquisitionAndFallbackTest.zeroHviRecovery();

            testCase.verifyEqual(index, 2);
        end

        function testFallbackExcludesInvalidCandidate(testCase)
            index = AcquisitionAndFallbackTest.invalidCandidateRecovery();

            testCase.verifyEqual(index, 3);
        end

        function testAllInvalidFallbackRequestsPoolRegeneration(testCase)
            [index, requiresRegeneration, allScoresNegativeInf] = ...
                AcquisitionAndFallbackTest.exhaustedFallbackPool();

            testCase.verifyEmpty(index);
            testCase.verifyTrue(requiresRegeneration);
            testCase.verifyTrue(allScoresNegativeInf);
        end
    end

    methods (Static, Access = private)
        function [front, indices] = knownPareto2d()
            Y = [1, 4; 2, 2; 4, 1; 3, 3; 2, 2; NaN, 0];
            [front, indices] = ctsemo.pareto2d(Y);
        end

        function hypervolume = knownHypervolume()
            Y = [1, 4; 2, 2; 4, 1; 3, 3; 2, 2];
            hypervolume = ctsemo.hypervolume2d(Y, [5, 5]);
        end

        function [hvi, requiresFallback] = knownSampledHvi()
            candidateObjectives = [1.5, 1.5; 3, 3; 6, 6];
            feasibleObjectives = [1, 4; 2, 2; 4, 1];
            [hvi, info] = ctsemo.sampledHVI( ...
                candidateObjectives, feasibleObjectives, [5, 5]);
            requiresFallback = info.requiresFallback;
        end

        function [hvi, reason, requiresFallback] = zeroSampledHvi()
            candidateObjectives = [3, 3; 4.5, 4.5];
            feasibleObjectives = [1, 4; 2, 2; 4, 1];
            [hvi, info] = ctsemo.sampledHVI( ...
                candidateObjectives, feasibleObjectives, [5, 5]);
            reason = info.reason;
            requiresFallback = info.requiresFallback;
        end

        function [score, epsilon, reason, requiresFallback] = ...
                fixedEpsilonZeroHvi()
            Xcandidate = [0.2, 0.2; 0.8, 0.8];
            Ycandidate = [3, 3; 4.5, 4.5];
            p_i = [0.5; 0.8];
            feasibleObjectives = [1, 4; 2, 2; 4, 1];
            options = cTSEMOOptions(struct( ...
                "acquisition", struct( ...
                    "epsilon", 0.2, "backgroundScale", 0), ...
                "masks", struct( ...
                    "design", struct("enabled", false), ...
                    "codomain", struct("enabled", false))));
            [score, components, status] = ctsemo.scoreCandidates( ...
                Xcandidate, Ycandidate, p_i, feasibleObjectives, ...
                [5, 5], [0, 0], [4.5, 4.5], options);
            epsilon = components.epsilon;
            reason = status.reason;
            requiresFallback = status.requiresFallback;
        end

        function [designMask, codomainMask] = disabledMaskValues()
            Xcandidate = [0.2, 0.2; 0.8, 0.8];
            Xtrain = [0, 0];
            Ycandidate = [1.5, 1.5; 3.5, 1.5];
            Ytrain = [2, 2];
            [designMask, codomainMask] = ctsemo.crowdingMasks( ...
                Xcandidate, Xtrain, Ycandidate, Ytrain, ...
                AcquisitionAndFallbackTest.scoreOptions());
        end

        function [designMask, hardDuplicate] = hardDuplicateMask()
            Xcandidate = [0, 0; 0.8, 0.8];
            Xtrain = [0, 0];
            Ycandidate = [1.5, 1.5; 3.5, 1.5];
            Ytrain = [2, 2];
            [designMask, ~, info] = ctsemo.crowdingMasks( ...
                Xcandidate, Xtrain, Ycandidate, Ytrain, ...
                AcquisitionAndFallbackTest.scoreOptions());
            hardDuplicate = info.hardDuplicate;
        end

        function [designMask, codomainMask] = nearAndFarMasks()
            Xcandidate = [0.01, 0; 0.8, 0.8];
            Xtrain = [0, 0];
            Ycandidate = [2.01, 2; 4, 4];
            Ytrain = [2, 2];
            options = cTSEMOOptions(struct( ...
                "masks", struct( ...
                    "design", struct( ...
                        "enabled", true, "radiusScale", 0.2), ...
                    "codomain", struct( ...
                        "enabled", true, "radiusScale", 0.2))));
            [designMask, codomainMask] = ctsemo.crowdingMasks( ...
                Xcandidate, Xtrain, Ycandidate, Ytrain, options);
        end

        function [score, expected, components] = factoredAcquisition()
            Xcandidate = [0.2, 0.2; 0.8, 0.8];
            Ycandidate = [1.5, 1.5; 3, 3];
            p_i = [0.8; 0.9];
            feasibleObjectives = [1, 4; 2, 2; 4, 1];
            [score, components] = ctsemo.scoreCandidates( ...
                Xcandidate, Ycandidate, p_i, feasibleObjectives, ...
                [5, 5], [0, 0], [4.5, 4.5], ...
                AcquisitionAndFallbackTest.scoreOptions());
            expected = [2.25 .* 0.8; 0];
        end

        function [score, expectedScore, epsilon, expectedEpsilon, ...
                pofPower] = poweredBackgroundAcquisition()
            Xcandidate = [0.2, 0.2; 0.8, 0.8];
            Ycandidate = [1.5, 1.5; 1.5, 1.5];
            p_i = [0.5; 0.8];
            feasibleObjectives = [1, 4; 2, 2; 4, 1];
            options = cTSEMOOptions(struct( ...
                "acquisition", struct("pofPower", 2), ...
                "masks", struct( ...
                    "design", struct("enabled", false), ...
                    "codomain", struct("enabled", false))));
            [score, components, status] = ctsemo.scoreCandidates( ...
                Xcandidate, Ycandidate, p_i, feasibleObjectives, ...
                [5, 5], [0, 0], [4.5, 4.5], options);
            expectedEpsilon = 0.25 .* 2.25;
            expectedScore = (2.25 + expectedEpsilon) .* p_i.^2;
            epsilon = components.epsilon;
            pofPower = status.pofPower;
        end

        function [score, hardDuplicate] = duplicateCandidateScore()
            Xcandidate = [0, 0; 0.8, 0.8];
            Ycandidate = [1.5, 1.5; 1.6, 1.6];
            feasibleObjectives = [1, 4; 2, 2; 4, 1];
            [score, components] = ctsemo.scoreCandidates( ...
                Xcandidate, Ycandidate, ones(2, 1), ...
                feasibleObjectives, [5, 5], [0, 0], [4.5, 4.5], ...
                AcquisitionAndFallbackTest.scoreOptions());
            hardDuplicate = components.hardDuplicate;
        end

        function [selectedSource, score] = ...
                sameAcquisitionArbitration()
            Xcandidate = [0.2, 0.2; 0.8, 0.8];
            Ycandidate = [3.5, 1.5; 1.5, 1.5];
            candidateSource = ["primary"; "challenger"];
            feasibleObjectives = [1, 4; 2, 2; 4, 1];
            score = ctsemo.scoreCandidates( ...
                Xcandidate, Ycandidate, ones(2, 1), ...
                feasibleObjectives, [5, 5], [0, 0], [4.5, 4.5], ...
                AcquisitionAndFallbackTest.scoreOptions());
            [~, selectedIndex] = max(score);
            selectedSource = candidateSource(selectedIndex);
        end

        function [index, phase, policy] = maximinRecovery()
            Xcandidate = [0.1, 0; 0.5, 0; 0.9, 0];
            [index, ~, info] = ctsemo.selectFallback( ...
                Xcandidate, zeros(3, 1), [0, 0], false(3, 1), ...
                "no_feasible_front", ...
                AcquisitionAndFallbackTest.fallbackOptions());
            phase = info.phase;
            policy = info.policy;
        end

        function index = zeroHviRecovery()
            Xcandidate = [0.1, 0; 0.5, 0; 0.9, 0];
            p_i = [0.1; 0.9; 0.7];
            index = ctsemo.selectFallback( ...
                Xcandidate, p_i, [0, 0], false(3, 1), ...
                "no_positive_hvi", ...
                AcquisitionAndFallbackTest.fallbackOptions());
        end

        function index = invalidCandidateRecovery()
            Xcandidate = [0.1, 0; 0.5, 0; 0.9, 0];
            p_i = [0.1; 0.9; 0.7];
            index = ctsemo.selectFallback( ...
                Xcandidate, p_i, [0, 0], logical([0; 1; 0]), ...
                "no_positive_hvi", ...
                AcquisitionAndFallbackTest.fallbackOptions());
        end

        function [index, requiresRegeneration, allScoresNegativeInf] = ...
                exhaustedFallbackPool()
            Xcandidate = [0.1, 0; 0.5, 0; 0.9, 0];
            [index, fallbackScore, info] = ctsemo.selectFallback( ...
                Xcandidate, [0.2; 0.8; 0.6], [0, 0], ...
                true(3, 1), "candidate_generation_failure", ...
                AcquisitionAndFallbackTest.fallbackOptions());
            requiresRegeneration = info.requiresCandidateRegeneration;
            allScoresNegativeInf = all( ...
                isinf(fallbackScore) & fallbackScore < 0);
        end

        function options = scoreOptions()
            options = cTSEMOOptions(struct( ...
                "acquisition", struct( ...
                    "pofPower", 1, ...
                    "epsilon", 0, ...
                    "backgroundScale", 0), ...
                "masks", struct( ...
                    "design", struct("enabled", false), ...
                    "codomain", struct("enabled", false))));
        end

        function options = fallbackOptions()
            options = cTSEMOOptions(struct( ...
                "fallback", struct( ...
                    "minPoF", 0.6, ...
                    "distanceScale", 0.1, ...
                    "distanceWeight", 1)));
        end
    end
end
