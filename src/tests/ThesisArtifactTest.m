classdef ThesisArtifactTest < matlab.unittest.TestCase
    %THESISARTIFACTTEST Validate thesis-specific public evidence and hygiene.

    properties (SetAccess = private)
        RepositoryRoot string
    end

    methods (TestClassSetup)
        function locateRepository(testCase)
            testFile = string(mfilename("fullpath"));
            testCase.RepositoryRoot = fileparts(fileparts(fileparts(testFile)));
        end
    end

    methods (Test, TestTags = {'Release', 'ThesisEvidence'})
        function testRetainedMatFilesContainNoPrivatePaths(testCase)
            files = dir(fullfile(testCase.RepositoryRoot, ...
                "manuscript", "artifacts", "**", "*.mat"));
            testCase.verifyGreaterThanOrEqual(numel(files), 41);
            hits = strings(0, 1);
            for fileIndex = 1:numel(files)
                pathValue = fullfile(files(fileIndex).folder, ...
                    files(fileIndex).name);
                loaded = load(pathValue);
                fileHits = ThesisArtifactTest.findPrivateText(loaded, ...
                    string(pathValue));
                hits = [hits; fileHits]; %#ok<AGROW>
            end
            testCase.verifyEmpty(hits, ...
                "Retained MAT records contain machine-specific paths.");
        end

        function testFinitePrimaryBundle(testCase)
            root = fullfile(testCase.RepositoryRoot, "manuscript", ...
                "artifacts", "finite_primary_ablation");
            evaluations = readtable(fullfile(root, ...
                "finite_primary_evaluations.csv"), TextType="string");
            runs = readtable(fullfile(root, ...
                "finite_primary_run_summary.csv"), TextType="string");
            summary = readtable(fullfile(root, ...
                "problem_ga_vs_finite_pool_pf_comparison.csv"), ...
                TextType="string");
            testCase.verifyEqual(height(evaluations), 5250);
            testCase.verifyEqual(height(runs), 35);
            testCase.verifyEqual(height(summary), 7);
            testCase.verifyEqual(unique(runs.PrimaryMethod), "finite_pool");
            testCase.verifyEqual(summary.MedianPairedHVChangePct, ...
                [-0.102437493076072; -0.720507561597684; ...
                 1.96730669249815; 0.741773457321537; ...
                 3.03602840625106; 0.833951720080484; ...
                -4.81262783835021], AbsTol=1e-12);
            testCase.verifyEqual(summary.HVWins, [2; 2; 3; 4; 3; 3; 2]);
            testCase.verifyEqual(summary.HVTies, [0; 0; 0; 0; 2; 0; 0]);
            testCase.verifyEqual(summary.HVLosses, [3; 3; 2; 1; 0; 2; 3]);
        end

        function testSelectionStateTotals(testCase)
            pathValue = fullfile(testCase.RepositoryRoot, "manuscript", ...
                "artifacts", "ga_primary_dimension", ...
                "selection_state_totals.csv");
            totals = readtable(pathValue);
            testCase.verifyEqual(table2array(totals), ...
                [3625, 68, 712, 145, 4550]);
        end

        function testWb150RetainedEvidence(testCase)
            root = fullfile(testCase.RepositoryRoot, "manuscript", ...
                "artifacts", "wb150_thesis", "data");
            validation = readtable(fullfile(root, ...
                "ctsemo_wb150_hvi_reconstruction_validation.csv"));
            selected = readtable(fullfile(root, ...
                "wb150_selected_iteration.csv"), TextType="string");
            testCase.verifyLessThanOrEqual(max(validation.AbsoluteError), 1e-9);
            testCase.verifyEqual(selected.Iteration, 130);
            testCase.verifyEqual(selected.EvaluationIndex, 150);
            testCase.verifyEqual(selected.SampledHVI, ...
                7.80430295740616, AbsTol=1e-12);
            testCase.verifyEqual(selected.FeasibilityScore, ...
                0.858606505638711, AbsTol=1e-12);
            testCase.verifyEqual(selected.Acquisition, ...
                6.791493144727, AbsTol=1e-12);
            testCase.verifyFalse(logical(selected.ObservedFeasible));
        end
    end

    methods (Static, Access = private)
        function hits = findPrivateText(value, path)
            hits = strings(0, 1);
            if isstruct(value)
                fields = fieldnames(value);
                for elementIndex = 1:numel(value)
                    for fieldIndex = 1:numel(fields)
                        field = fields{fieldIndex};
                        hits = [hits; ThesisArtifactTest.findPrivateText( ...
                            value(elementIndex).(field), path + "." + field)]; %#ok<AGROW>
                    end
                end
            elseif iscell(value)
                for elementIndex = 1:numel(value)
                    hits = [hits; ThesisArtifactTest.findPrivateText( ...
                        value{elementIndex}, path + "{" + elementIndex + "}")]; %#ok<AGROW>
                end
            elseif ischar(value) || isstring(value)
                values = string(value);
                profileToken = "One" + "Drive\\\\Desktop";
                homeToken = "/" + "home" + "/[^/]+/";
                pattern = "(?i)[A-Z]:\\\\Users\\\\|" + profileToken + "|" + ...
                    "\\\\\\\\(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\\\|" + ...
                    homeToken;
                for elementIndex = 1:numel(values)
                    if ~isempty(regexp(values(elementIndex), pattern, "once"))
                        hits(end + 1, 1) = path; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
