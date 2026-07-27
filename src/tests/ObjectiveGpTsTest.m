classdef ObjectiveGpTsTest < matlab.unittest.TestCase
    %ObjectiveGpTsTest Exact objective-GP and Thompson-draw tests.

    methods (TestClassSetup)
        function addReleasePath(testCase)
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                releaseRoot));
        end
    end

    methods (Test, TestTags = {'Unit', 'ObjectiveGP'})
        function testPosteriorPredictionIsFinite(testCase)
            [meanPrediction, variancePrediction] = ...
                ObjectiveGpTsTest.posteriorPrediction();

            testCase.verifySize(meanPrediction, [3, 1]);
            testCase.verifySize(variancePrediction, [3, 1]);
            testCase.verifyTrue(all(isfinite(meanPrediction)));
            testCase.verifyTrue(all(isfinite(variancePrediction)));
            testCase.verifyGreaterThanOrEqual(variancePrediction, ...
                zeros(size(variancePrediction)));
        end

        function testSameSeedProducesSameDraw(testCase)
            [firstValue, secondValue, firstSeed, secondSeed] = ...
                ObjectiveGpTsTest.repeatedDrawValues();

            testCase.verifyEqual(firstValue, secondValue, ...
                AbsTol=1.0e-13);
            testCase.verifyEqual(firstSeed, secondSeed);
        end

        function testDifferentDrawIndexProducesDifferentDraw(testCase)
            differenceNorm = ObjectiveGpTsTest.differentDrawDifference();

            testCase.verifyGreaterThan(differenceNorm, 1.0e-12);
        end

        function testThompsonDrawRestoresCallerRng(testCase)
            [before, after] = ObjectiveGpTsTest.rngAroundDraw();

            testCase.verifyEqual(after, before);
        end

        function testBaseQuantilesMatchFormerSpectralDefinition(testCase)
            [frequencyError, phaseError] = ...
                ObjectiveGpTsTest.formerDefinitionErrors();

            testCase.verifyLessThanOrEqual(frequencyError, 5.0e-13);
            testCase.verifyEqual(phaseError, 0);
        end

        function testSpectralDrawFieldsAndValuesAreFinite(testCase)
            [drawValues, storedValues] = ...
                ObjectiveGpTsTest.finiteDrawValues();

            testCase.verifyTrue(all(isfinite(drawValues)));
            testCase.verifyTrue(all(isfinite(storedValues)));
        end

        function testPhysicalInputBoundsAreHonored(testCase)
            prediction = ObjectiveGpTsTest.physicalBoundPrediction();

            testCase.verifySize(prediction, [2, 1]);
            testCase.verifyTrue(all(isfinite(prediction)));
        end
    end

    methods (Static, Access = private)
        function [meanPrediction, variancePrediction] = ...
                posteriorPrediction()
            model = ObjectiveGpTsTest.fittedNormalizedModel();
            query = [0.1, 0.2; 0.5, 0.5; 0.9, 0.8];
            [meanPrediction, variancePrediction] = ...
                ctsemo.predictObjectiveGP(model, query);
        end

        function [firstValue, secondValue, firstSeed, secondSeed] = ...
                repeatedDrawValues()
            model = ObjectiveGpTsTest.fittedNormalizedModel();
            options = struct( ...
                "nFeatures", 64, ...
                "baseSeed", 19, ...
                "objectiveIndex", 1, ...
                "drawIndex", 3);
            firstDraw = ctsemo.drawObjectiveTS(model, options);
            secondDraw = ctsemo.drawObjectiveTS(model, options);
            query = [0.15, 0.2; 0.5, 0.6; 0.85, 0.3];
            firstValue = ctsemo.evaluateObjectiveTS(firstDraw, query);
            secondValue = ctsemo.evaluateObjectiveTS(secondDraw, query);
            firstSeed = firstDraw.seed;
            secondSeed = secondDraw.seed;
        end

        function differenceNorm = differentDrawDifference()
            model = ObjectiveGpTsTest.fittedNormalizedModel();
            firstDraw = ctsemo.drawObjectiveTS(model, struct( ...
                "nFeatures", 64, ...
                "baseSeed", 19, ...
                "objectiveIndex", 1, ...
                "drawIndex", 3));
            secondDraw = ctsemo.drawObjectiveTS(model, struct( ...
                "nFeatures", 64, ...
                "baseSeed", 19, ...
                "objectiveIndex", 1, ...
                "drawIndex", 4));
            query = [0.15, 0.2; 0.5, 0.6; 0.85, 0.3];
            firstValue = ctsemo.evaluateObjectiveTS(firstDraw, query);
            secondValue = ctsemo.evaluateObjectiveTS(secondDraw, query);
            differenceNorm = norm(firstValue - secondValue);
        end

        function [before, after] = rngAroundDraw()
            model = ObjectiveGpTsTest.fittedNormalizedModel();
            rng(8128, "twister");
            before = rng;
            ctsemo.drawObjectiveTS(model, struct( ...
                "nFeatures", 32, ...
                "baseSeed", 17, ...
                "objectiveIndex", 2, ...
                "drawIndex", 5));
            after = rng;
        end

        function [frequencyError, phaseError] = ...
                formerDefinitionErrors()
            model = ObjectiveGpTsTest.fittedNormalizedModel();
            drawOptions = struct( ...
                "nFeatures", 128, ...
                "baseSeed", 29, ...
                "objectiveIndex", 2, ...
                "drawIndex", 7);
            draw = ctsemo.drawObjectiveTS(model, drawOptions);
            [formerFrequencies, formerPhases] = ...
                ObjectiveGpTsTest.formerSpectralParameters( ...
                    model, drawOptions, draw.seed);
            frequencyError = max(abs( ...
                draw.frequencies - formerFrequencies), [], "all");
            phaseError = max(abs(draw.phases - formerPhases));
        end

        function [drawValues, storedValues] = finiteDrawValues()
            model = ObjectiveGpTsTest.fittedNormalizedModel();
            draw = ctsemo.drawObjectiveTS(model, struct( ...
                "nFeatures", 256, ...
                "baseSeed", 31, ...
                "objectiveIndex", 1, ...
                "drawIndex", 9));
            query = linspace(0, 1, 33).';
            query = [query, 1 - query];
            drawValues = ctsemo.evaluateObjectiveTS(draw, query);
            storedValues = [draw.frequencies(:); draw.phases(:); ...
                draw.featureWeights(:); draw.correctionWeights(:)];
        end

        function [frequencies, phases] = formerSpectralParameters( ...
                model, options, seed)
            rngCleanup = ctsemo.scopedRng(seed); %#ok<NASGU>
            dimension = model.dimension;
            pointCount = options.nFeatures;
            design = zeros(pointCount, dimension + 2);
            for dimensionIndex = 1:(dimension + 2)
                strata = randperm(pointCount).';
                design(:, dimensionIndex) = ...
                    (strata - rand(pointCount, 1)) ./ pointCount;
            end
            probabilityTolerance = sqrt(eps);
            design = min(max(design, probabilityTolerance), ...
                1 - probabilityTolerance);

            normalProbability = design(:, 1:dimension);
            chiProbability = design(:, dimension + 1);
            if exist("norminv", "file") == 2 && ...
                    exist("chi2inv", "file") == 2
                normalQuantile = norminv(normalProbability, 0, 1);
                chiQuantile = chi2inv(chiProbability, ...
                    model.spectralDegreesOfFreedom);
            else
                normalQuantile = sqrt(2) .* ...
                    erfinv(2 .* normalProbability - 1);
                chiQuantile = 2 .* gammaincinv(chiProbability, ...
                    model.spectralDegreesOfFreedom ./ 2, "lower");
            end
            frequencies = normalQuantile .* sqrt( ...
                model.spectralDegreesOfFreedom ./ chiQuantile) ./ ...
                model.lengthScale;
            phases = 2 .* pi .* design(:, dimension + 2);
        end

        function prediction = physicalBoundPrediction()
            X = [-2, 10; 0, 15; 2, 20; 1, 12; -1, 18];
            y = sum(X.^2, 2);
            options = ObjectiveGpTsTest.fastGpOptions();
            options.inputLowerBound = [-2, 10];
            options.inputUpperBound = [2, 20];
            model = ctsemo.fitObjectiveGP(X, y, options);
            draw = ctsemo.drawObjectiveTS(model, struct( ...
                "nFeatures", 48, "seed", 23));
            prediction = ctsemo.evaluateObjectiveTS( ...
                draw, [-1.5, 11; 1.5, 19]);
        end

        function model = fittedNormalizedModel()
            X = [0, 0; 0, 1; 0.5, 0.25; 0.7, 0.8; 1, 0; 1, 1];
            y = sin(2 .* pi .* X(:, 1)) + X(:, 2).^2;
            model = ctsemo.fitObjectiveGP( ...
                X, y, ObjectiveGpTsTest.fastGpOptions());
        end

        function options = fastGpOptions()
            options = struct( ...
                "kernel", "matern32", ...
                "nFeatures", 64, ...
                "jitter", 1.0e-10, ...
                "standardizeY", true, ...
                "noiseLower", 1.0e-8, ...
                "noiseUpper", 1.0e-3, ...
                "optimizeHyperparameters", false, ...
                "baseSeed", 11);
        end
    end
end
