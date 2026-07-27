classdef LocalMatern32Test < matlab.unittest.TestCase
    %LocalMatern32Test Covariance symmetry and positive-definiteness tests.

    methods (TestClassSetup)
        function addReleasePath(testCase)
            releaseRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                releaseRoot));
        end
    end

    methods (Test, TestTags = {'Unit', 'PoF'})
        function testTwoDimensionalKernelIsSymmetric(testCase)
            covariance = LocalMatern32Test.twoDimensionalCovariance();

            testCase.verifyEqual(covariance, covariance', ...
                AbsTol=1.0e-13);
            testCase.verifyEqual(diag(covariance), ...
                ones(size(covariance, 1), 1), AbsTol=1.0e-13);
        end

        function testTwoDimensionalKernelIsPositiveDefinite(testCase)
            minimumEigenvalue = ...
                LocalMatern32Test.twoDimensionalMinimumEigenvalue();

            testCase.verifyGreaterThan(minimumEigenvalue, 0);
        end

        function testFourDimensionalKernelIsSymmetric(testCase)
            covariance = LocalMatern32Test.fourDimensionalCovariance();

            testCase.verifyEqual(covariance, covariance', ...
                AbsTol=1.0e-13);
            testCase.verifyEqual(diag(covariance), ...
                ones(size(covariance, 1), 1), AbsTol=1.0e-13);
        end

        function testFourDimensionalKernelIsPositiveDefinite(testCase)
            minimumEigenvalue = ...
                LocalMatern32Test.fourDimensionalMinimumEigenvalue();

            testCase.verifyGreaterThan(minimumEigenvalue, 0);
        end

        function testCrossCovarianceHasExpectedShape(testCase)
            covariance = LocalMatern32Test.crossCovariance();

            testCase.verifySize(covariance, [3, 2]);
            testCase.verifyGreaterThanOrEqual(covariance, ...
                zeros(size(covariance)));
            testCase.verifyLessThanOrEqual(covariance, ...
                ones(size(covariance)));
        end
    end

    methods (Static, Access = private)
        function covariance = twoDimensionalCovariance()
            X = [0.05, 0.15; 0.2, 0.8; 0.45, 0.35; ...
                0.75, 0.9; 0.95, 0.1];
            lengths = [0.08; 0.15; 0.3; 0.5; 0.9];
            covariance = ctsemo.localMatern32( ...
                X, lengths, X, lengths);
        end

        function value = twoDimensionalMinimumEigenvalue()
            covariance = LocalMatern32Test.twoDimensionalCovariance();
            value = min(eig(0.5 .* (covariance + covariance')));
        end

        function covariance = fourDimensionalCovariance()
            X = [ ...
                0.05, 0.15, 0.25, 0.35; ...
                0.2, 0.8, 0.4, 0.6; ...
                0.45, 0.35, 0.75, 0.1; ...
                0.75, 0.9, 0.2, 0.55; ...
                0.95, 0.1, 0.85, 0.7; ...
                0.6, 0.5, 0.45, 0.4];
            lengths = [0.08; 0.15; 0.3; 0.5; 0.9; 0.22];
            covariance = ctsemo.localMatern32( ...
                X, lengths, X, lengths);
        end

        function value = fourDimensionalMinimumEigenvalue()
            covariance = LocalMatern32Test.fourDimensionalCovariance();
            value = min(eig(0.5 .* (covariance + covariance')));
        end

        function covariance = crossCovariance()
            X1 = [0, 0; 0.5, 0.5; 1, 1];
            X2 = [0.25, 0.75; 0.75, 0.25];
            covariance = ctsemo.localMatern32( ...
                X1, [0.1; 0.2; 0.3], X2, [0.15; 0.4]);
        end
    end
end
