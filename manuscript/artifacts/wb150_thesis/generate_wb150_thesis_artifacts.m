function outputs = generate_wb150_thesis_artifacts(outputRoot)
%GENERATE_WB150_THESIS_ARTIFACTS Rebuild the thesis-specific WB150 evidence.

scriptDir = fileparts(mfilename('fullpath'));
repositoryRoot = fileparts(fileparts(fileparts(scriptDir)));
sourceRoot = fullfile(repositoryRoot, 'src');
studyRoot = fullfile(repositoryRoot, 'manuscript', 'artifacts', ...
    'ga_primary_dimension');
if nargin < 1 || strlength(string(outputRoot)) == 0
    outputRoot = fullfile(repositoryRoot, 'generated', 'wb150_thesis');
end
outputRoot = char(outputRoot);
imageRoot = fullfile(outputRoot, 'figures');
pdfRoot = fullfile(outputRoot, 'pdf');
dataRoot = fullfile(outputRoot, 'data');

assert(isfolder(sourceRoot), 'Source-sealed cTSEMO package was not found.');
assert(isfolder(studyRoot), 'Source-sealed WB150 study was not found.');
if ~isfolder(imageRoot)
    mkdir(imageRoot);
end
if ~isfolder(pdfRoot)
    mkdir(pdfRoot);
end
if ~isfolder(dataRoot)
    mkdir(dataRoot);
end

addpath(sourceRoot);
pathCleanup = onCleanup(@() rmpath(sourceRoot));

profilePdf = fullfile(imageRoot, 'ctsemo_wb150_hvi_profiles.pdf');
pairwisePdf = fullfile(imageRoot, 'ctsemo_wb150_hvi_pairwise.pdf');
evolutionRoot = fullfile(pdfRoot, 'pareto_evolution_frames');

[result, representative] = loadRepresentativeRun(studyRoot);
[profileTable, sliceTable, validationTable, conditionalData] = ...
    reconstructFinalHviFields(result);
selectedTable = selectedIterationTable(result, representative.Replicate);
evaluationCount = size(result.data.Y, 1);
evaluationTable = table((1:evaluationCount).', ...
    (1:evaluationCount).' <= result.data.nInitial, ...
    logical(result.data.isFeasible(:)), result.data.Y(:, 1), ...
    result.data.Y(:, 2), 'VariableNames', ...
    {'Evaluation', 'IsInitial', 'IsFeasible', 'f1', 'f2'});

writetable(profileTable, fullfile(dataRoot, ...
    'ctsemo_wb150_hvi_profiles.csv'));
writetable(sliceTable, fullfile(dataRoot, ...
    'ctsemo_wb150_hvi_pairwise.csv'));
writetable(validationTable, fullfile(dataRoot, ...
    'ctsemo_wb150_hvi_reconstruction_validation.csv'));
writetable(selectedTable, fullfile(dataRoot, ...
    'wb150_selected_iteration.csv'));
retainedSelected = readtable(fullfile(scriptDir, 'data', ...
    'wb150_selected_iteration.csv'), 'TextType', 'string');
assertSelectedEvidenceMatches(selectedTable, retainedSelected);

buildHviProfiles(profileTable, profilePdf);
buildHviPairwiseSlices(sliceTable, pairwisePdf);
conditionalPdfs = buildConditionalHviArtifacts( ...
    conditionalData, imageRoot, dataRoot);
finalFramePdf = buildParetoEvolution(evaluationTable, evolutionRoot);

outputs = struct( ...
    'hviProfiles', profilePdf, ...
    'hviPairwiseSlices', pairwisePdf, ...
    'hviConditionalInputs', conditionalPdfs, ...
    'paretoEvolutionFrames', evolutionRoot, ...
    'paretoFinalFrame', finalFramePdf, ...
    'representativeReplicate', representative.Replicate, ...
    'representativeFinalNormalizedHV', representative.FinalNormalizedHV);
disp(outputs)
end

function output = selectedIterationTable(result, replicate)
record = result.iterations(end);
evaluationIndex = double(record.evaluationIndex);
selected = record.selected;
output = table( ...
    double(replicate), double(record.iteration), evaluationIndex, ...
    double(selected.X(1)), double(selected.X(2)), ...
    double(selected.X(3)), double(selected.X(4)), ...
    double(selected.sampledHVI), double(selected.pof), ...
    double(selected.AF), string(selected.candidateSource), ...
    string(selected.origin), ...
    logical(result.data.isFeasible(evaluationIndex)), ...
    'VariableNames', {'Replicate', 'Iteration', 'EvaluationIndex', ...
    'X1', 'X2', 'X3', 'X4', 'SampledHVI', ...
    'FeasibilityScore', 'Acquisition', 'CandidateSource', ...
    'Origin', 'ObservedFeasible'});
end

function assertSelectedEvidenceMatches(actual, expected)
assert(isequal(actual.Properties.VariableNames, ...
    expected.Properties.VariableNames), ...
    'Retained selected-iteration schema differs from the reconstruction.');
for variable = string(actual.Properties.VariableNames)
    a = actual.(variable);
    b = expected.(variable);
    if isnumeric(a) || islogical(a)
        assert(all(abs(double(a) - double(b)) <= 1e-12, 'all'), ...
            'Retained selected-iteration value differs for %s.', variable);
    else
        assert(isequal(string(a), string(b)), ...
            'Retained selected-iteration text differs for %s.', variable);
    end
end
end

function [result, representative] = loadRepresentativeRun(studyRoot)
perRun = readtable(fullfile(studyRoot, ...
    'ga_primary_highdim_per_run.csv'), 'VariableNamingRule', 'preserve');
weldedBeam = perRun(strcmp(perRun.ProblemId, 'WELDEDBEAM'), :);
assert(height(weldedBeam) == 5, ...
    'Expected five source-sealed welded-beam replicates.');
weldedBeam = sortrows(weldedBeam, 'FinalNormalizedHV');
representative = weldedBeam(3, :);
replicate = representative.Replicate;
resultFile = fullfile(studyRoot, 'runs', ...
    sprintf('WELDEDBEAM_rep%02d', replicate), 'result.mat');
assert(isfile(resultFile), ...
    'Expected the retained result file for the representative replicate.');
loaded = load(resultFile, 'result');
result = loaded.result;
assert(size(result.data.Y, 1) == 150 && result.data.nInitial == 20, ...
    'Representative WB150 result has an unexpected evaluation count.');
assert(result.pareto.nPoints == representative.FinalParetoCount, ...
    'Representative result does not match the retained run summary.');
end

function [profileTable, sliceTable, validationTable, conditionalData] = ...
        reconstructFinalHviFields(result)
iteration = numel(result.iterations);
assert(iteration == 130, 'Expected 130 sequential WB150 iterations.');
record = result.iterations(end);
trainingCount = record.evaluationIndex - 1;
assert(trainingCount == 149, ...
    'Final acquisition model must be trained on evaluations 1-149.');

lowerBound = double(result.problem.lowerBound(:).');
upperBound = double(result.problem.upperBound(:).');
inputRange = upperBound - lowerBound;
xTraining = double(result.data.X(1:trainingCount, :));
yTraining = double(result.data.Y(1:trainingCount, :));
isFeasible = logical(result.data.isFeasible(1:trainingCount));
xUnit = (xTraining - lowerBound) ./ inputRange;
[yStandardized, objectiveCenter, objectiveScale] = ...
    standardizeObjectives(yTraining);
feasibleObjectives = yStandardized(isFeasible, :);
referencePoint = acquisitionReference(feasibleObjectives);

draws = cell(1, 2);
for objectiveIndex = 1:2
    fitOptions = result.options.objectiveGP;
    fitOptions.baseSeed = ctsemo.componentSeed( ...
        result.options.seed, 'objective-fit', [iteration, objectiveIndex]);
    model = ctsemo.fitObjectiveGP( ...
        xUnit, yTraining(:, objectiveIndex), fitOptions);
    drawOptions = result.options.objectiveGP;
    drawOptions.baseSeed = result.options.seed;
    drawOptions.objectiveIndex = objectiveIndex;
    drawOptions.drawIndex = iteration;
    draws{objectiveIndex} = ctsemo.drawObjectiveTS(model, drawOptions);
end

selectedUnit = double(record.selected.XUnit(:).');
selectedDraw = evaluateDraws(draws, selectedUnit);
selectedStandardized = ...
    (selectedDraw - objectiveCenter) ./ objectiveScale;
selectedHvi = ctsemo.sampledHVI( ...
    selectedStandardized, feasibleObjectives, referencePoint);
drawError = max(abs(selectedDraw - double(record.selected.YDraw(:).')));
hviError = abs(selectedHvi - double(record.selected.sampledHVI));
referenceError = max(abs(referencePoint - ...
    double(record.acquisitionReferencePoint(:).')));
centerError = max(abs(objectiveCenter - ...
    double(record.objectiveScaling.center(:).')));
scaleError = max(abs(objectiveScale - ...
    double(record.objectiveScaling.scale(:).')));
assert(drawError < 1.0e-9 && hviError < 1.0e-10 && ...
    referenceError < 1.0e-12 && centerError < 1.0e-12 && ...
    scaleError < 1.0e-12, ...
    'Final source-sealed HVI reconstruction did not match the stored record.');

profileTable = buildProfileTable(draws, feasibleObjectives, ...
    referencePoint, objectiveCenter, objectiveScale, ...
    lowerBound, inputRange, result.options.seed, iteration);
sliceTable = buildSliceTable(draws, feasibleObjectives, ...
    referencePoint, objectiveCenter, objectiveScale, ...
    lowerBound, inputRange, xUnit);
conditionalData = buildConditionalHviData(draws, feasibleObjectives, ...
    referencePoint, objectiveCenter, objectiveScale, lowerBound, ...
    inputRange, selectedUnit, selectedHvi, result.options.seed, iteration, ...
    trainingCount);
validationTable = table( ...
    ["SelectedYDrawMaxAbsError"; "SelectedHVIAbsError"; ...
    "ReferencePointMaxAbsError"; "ObjectiveCenterMaxAbsError"; ...
    "ObjectiveScaleMaxAbsError"], ...
    [drawError; hviError; referenceError; centerError; scaleError], ...
    'VariableNames', {'Check', 'AbsoluteError'});
end

function profileTable = buildProfileTable(draws, feasibleObjectives, ...
        referencePoint, objectiveCenter, objectiveScale, ...
        lowerBound, inputRange, baseSeed, iteration)
gridCount = 31;
nuisanceCount = 64;
grid = linspace(0, 1, gridCount).';
nuisance = latinHypercube(nuisanceCount, 4, ...
    ctsemo.componentSeed(baseSeed, 'chapter3-hvi-profile', iteration));

rowCount = 4 * gridCount;
quantity = repmat("HVI_draw", rowCount, 1);
inputIndexColumn = zeros(rowCount, 1);
gridIndexColumn = zeros(rowCount, 1);
inputScaled = zeros(rowCount, 1);
inputPhysical = zeros(rowCount, 1);
meanValue = zeros(rowCount, 1);
medianValue = zeros(rowCount, 1);
q10 = zeros(rowCount, 1);
q90 = zeros(rowCount, 1);

row = 0;
for inputIndex = 1:4
    for gridIndex = 1:gridCount
        probes = nuisance;
        probes(:, inputIndex) = grid(gridIndex);
        hvi = evaluateHvi(draws, probes, objectiveCenter, ...
            objectiveScale, feasibleObjectives, referencePoint);
        row = row + 1;
        inputIndexColumn(row) = inputIndex;
        gridIndexColumn(row) = gridIndex;
        inputScaled(row) = grid(gridIndex);
        inputPhysical(row) = lowerBound(inputIndex) + ...
            grid(gridIndex) * inputRange(inputIndex);
        meanValue(row) = mean(hvi);
        medianValue(row) = median(hvi);
        q10(row) = empiricalQuantile(hvi, 0.10);
        q90(row) = empiricalQuantile(hvi, 0.90);
    end
end

profileTable = table(quantity, inputIndexColumn, gridIndexColumn, ...
    inputScaled, inputPhysical, meanValue, medianValue, q10, q90, ...
    'VariableNames', {'Quantity', 'Input', 'GridIndex', 'InputScaled', ...
    'InputPhysical', 'Mean', 'Median', 'Q10', 'Q90'});
end

function sliceTable = buildSliceTable(draws, feasibleObjectives, ...
        referencePoint, objectiveCenter, objectiveScale, ...
        lowerBound, inputRange, xTrainingUnit)
pairs = [1, 2; 1, 3; 1, 4; 2, 3; 2, 4; 3, 4];
grid = linspace(0, 1, 25);
[gridA, gridB] = meshgrid(grid, grid);
pointsPerPair = numel(gridA);
rowCount = size(pairs, 1) * pointsPerPair;
pairId = zeros(rowCount, 1);
inputAColumn = zeros(rowCount, 1);
inputBColumn = zeros(rowCount, 1);
gridAColumn = zeros(rowCount, 1);
gridBColumn = zeros(rowCount, 1);
xPhysical = zeros(rowCount, 4);
hviColumn = zeros(rowCount, 1);
reference = median(xTrainingUnit, 1);

row = 0;
for pairIndex = 1:size(pairs, 1)
    inputA = pairs(pairIndex, 1);
    inputB = pairs(pairIndex, 2);
    probes = repmat(reference, pointsPerPair, 1);
    probes(:, inputA) = gridA(:);
    probes(:, inputB) = gridB(:);
    hvi = evaluateHvi(draws, probes, objectiveCenter, ...
        objectiveScale, feasibleObjectives, referencePoint);
    rows = row + (1:pointsPerPair);
    pairId(rows) = pairIndex;
    inputAColumn(rows) = inputA;
    inputBColumn(rows) = inputB;
    gridAColumn(rows) = gridA(:);
    gridBColumn(rows) = gridB(:);
    xPhysical(rows, :) = lowerBound + probes .* inputRange;
    hviColumn(rows) = hvi;
    row = row + pointsPerPair;
end

sliceTable = table(pairId, inputAColumn, inputBColumn, ...
    gridAColumn, gridBColumn, xPhysical(:, 1), xPhysical(:, 2), ...
    xPhysical(:, 3), xPhysical(:, 4), hviColumn, ...
    'VariableNames', {'PairId', 'InputA', 'InputB', 'GridA', 'GridB', ...
    'x1', 'x2', 'x3', 'x4', 'HVI_draw'});
end

function conditionalData = buildConditionalHviData(draws, ...
        feasibleObjectives, referencePoint, objectiveCenter, objectiveScale, ...
        lowerBound, inputRange, selectedUnit, selectedHvi, baseSeed, ...
        iteration, trainingCount)
sampleCount = 2048;
stationCount = 121;
thresholdCount = 181;
nuisanceSeed = ctsemo.componentSeed( ...
    baseSeed, 'chapter3-hvi-conditional', iteration);
nuisanceUnit = latinHypercube(sampleCount, 3, nuisanceSeed);
stationsUnit = linspace(0, 1, stationCount).';
hviRaw = zeros(sampleCount, stationCount, 4);

for inputIndex = 1:4
    nuisanceIndices = setdiff(1:4, inputIndex, 'stable');
    for stationIndex = 1:stationCount
        queryUnit = zeros(sampleCount, 4);
        queryUnit(:, inputIndex) = stationsUnit(stationIndex);
        queryUnit(:, nuisanceIndices) = nuisanceUnit;
        hviRaw(:, stationIndex, inputIndex) = evaluateHvi( ...
            draws, queryUnit, objectiveCenter, objectiveScale, ...
            feasibleObjectives, referencePoint);
    end
end

normalizationMaximum = max([hviRaw(:); selectedHvi]);
assert(normalizationMaximum > 0, ...
    'The reconstructed WB150 HVI field is identically zero.');
positiveTolerance = max(1.0e-14, 1.0e-12 * normalizationMaximum);
thresholdsNormalized = logspace(-8, 0, thresholdCount).';
survivalFloor = 1 / sampleCount;
selectedPhysical = lowerBound + selectedUnit .* inputRange;

symbols = ["h", "l", "t", "b"];
displayNames = ["weld thickness", "weld length", ...
    "beam depth", "beam thickness"];
axisLabels = ["Weld thickness, h [in]", "Weld length, l [in]", ...
    "Beam depth, t [in]", "Beam thickness, b [in]"];

conditionalData = repmat(struct(), 4, 1);
for inputIndex = 1:4
    normalizedHvi = hviRaw(:, :, inputIndex) ./ normalizationMaximum;
    positiveFraction = mean( ...
        hviRaw(:, :, inputIndex) > positiveTolerance, 1).';
    meanNormalized = mean(normalizedHvi, 1).';
    quantilesNormalized = columnQuantiles( ...
        normalizedHvi, [0.50, 0.90, 0.99]).';
    profileMaximum = max(normalizedHvi, [], 1).';
    conditionalSurvival = zeros(thresholdCount, stationCount);
    for stationIndex = 1:stationCount
        conditionalSurvival(:, stationIndex) = mean( ...
            normalizedHvi(:, stationIndex).' > thresholdsNormalized, 2);
    end
    conditionalLogSurvival = log10(max( ...
        conditionalSurvival, survivalFloor));
    inputPhysical = lowerBound(inputIndex) + ...
        stationsUnit .* inputRange(inputIndex);
    [lastPositiveInput, firstPermanentZeroInput] = supportCutoff( ...
        inputPhysical, positiveFraction);
    nuisanceIndices = setdiff(1:4, inputIndex, 'stable');

    conditionalData(inputIndex).InputIndex = inputIndex;
    conditionalData(inputIndex).Symbol = symbols(inputIndex);
    conditionalData(inputIndex).DisplayName = displayNames(inputIndex);
    conditionalData(inputIndex).AxisLabel = axisLabels(inputIndex);
    conditionalData(inputIndex).NuisanceSymbols = symbols(nuisanceIndices);
    conditionalData(inputIndex).InputPhysical = inputPhysical;
    conditionalData(inputIndex).HviRaw = hviRaw(:, :, inputIndex);
    conditionalData(inputIndex).HviNormalized = normalizedHvi;
    conditionalData(inputIndex).ThresholdsNormalized = thresholdsNormalized;
    conditionalData(inputIndex).ConditionalSurvival = conditionalSurvival;
    conditionalData(inputIndex).ConditionalLogSurvival = ...
        conditionalLogSurvival;
    conditionalData(inputIndex).PositiveFraction = positiveFraction;
    conditionalData(inputIndex).MeanNormalized = meanNormalized;
    conditionalData(inputIndex).QuantilesNormalized = quantilesNormalized;
    conditionalData(inputIndex).ProfileMaximum = profileMaximum;
    conditionalData(inputIndex).SelectedInput = selectedPhysical(inputIndex);
    conditionalData(inputIndex).SelectedHviNormalized = ...
        selectedHvi / normalizationMaximum;
    conditionalData(inputIndex).LastPositiveInput = lastPositiveInput;
    conditionalData(inputIndex).FirstPermanentZeroInput = ...
        firstPermanentZeroInput;
    conditionalData(inputIndex).SampleCount = sampleCount;
    conditionalData(inputIndex).StationCount = stationCount;
    conditionalData(inputIndex).NuisanceSeed = nuisanceSeed;
    conditionalData(inputIndex).NormalizationMaximum = ...
        normalizationMaximum;
    conditionalData(inputIndex).PositiveTolerance = positiveTolerance;
    conditionalData(inputIndex).Iteration = iteration;
    conditionalData(inputIndex).TrainingCount = trainingCount;
end
end

function pdfPaths = buildConditionalHviArtifacts( ...
        conditionalData, imageRoot, dataRoot)
pdfPaths = strings(4, 1);
for inputIndex = 1:4
    data = conditionalData(inputIndex);
    fileStem = sprintf('ctsemo_wb150_hvi_conditional_x%d', inputIndex);
    pdfPaths(inputIndex) = fullfile(imageRoot, [fileStem '.pdf']);
    plotConditionalHviFigure(data, pdfPaths(inputIndex));

    summaryTable = table(data.InputPhysical, data.PositiveFraction, ...
        data.MeanNormalized, data.QuantilesNormalized(:, 1), ...
        data.QuantilesNormalized(:, 2), data.QuantilesNormalized(:, 3), ...
        data.ProfileMaximum, 'VariableNames', ...
        {'InputPhysical', 'PositiveHviFraction', 'MeanNormalizedHvi', ...
        'MedianNormalizedHvi', 'P90NormalizedHvi', ...
        'P99NormalizedHvi', 'SampledProfileMaximumNormalizedHvi'});
    writetable(summaryTable, fullfile(dataRoot, [fileStem '.csv']));
end
save(fullfile(dataRoot, 'ctsemo_wb150_hvi_conditional.mat'), ...
    'conditionalData', '-v7');
end

function plotConditionalHviFigure(data, outputFile)
etaSymbol = string(char(951));
colors.blue = [23, 105, 170] ./ 255;
colors.orange = [232, 110, 23] ./ 255;
colors.gold = [213, 158, 26] ./ 255;
colors.red = [179, 58, 58] ./ 255;
colors.grey = [85, 91, 99] ./ 255;
colors.grid = [217, 221, 227] ./ 255;

fig = figure('Visible', 'off', 'Color', 'white', 'Units', 'inches', ...
    'Position', [0.5, 0.5, 7.5, 10.2]);
axesPositions = [ ...
    0.115, 0.720, 0.665, 0.200; ...
    0.115, 0.445, 0.665, 0.200; ...
    0.115, 0.170, 0.665, 0.200];
ax1 = axes(fig, 'Units', 'normalized', ...
    'Position', axesPositions(1, :), ...
    'PositionConstraint', 'innerposition');
imagesc(ax1, data.InputPhysical, log10(data.ThresholdsNormalized), ...
    data.ConditionalLogSurvival);
axis(ax1, 'xy');
hold(ax1, 'on');
[contours, contourHandle] = contour(ax1, data.InputPhysical, ...
    log10(data.ThresholdsNormalized), data.ConditionalSurvival, ...
    [0.01, 0.1, 0.5], 'LineColor', [0.12, 0.12, 0.12], ...
    'LineWidth', 0.9);
clabel(contours, contourHandle, 'FontName', 'Times New Roman', ...
    'FontSize', 8.5, 'Color', [0.12, 0.12, 0.12], ...
    'LabelSpacing', 420, 'Interpreter', 'none');
hold(ax1, 'off');
setTimesStyle(ax1);
set(ax1, 'Layer', 'top');
xlim(ax1, [data.InputPhysical(1), data.InputPhysical(end)]);
ylim(ax1, [-8, 0]);
yticks(ax1, -8:2:0);
yticklabels(ax1, compose('1e%d', -8:2:0));
xlabel(ax1, data.AxisLabel);
ylabel(ax1, "Normalized HVI threshold, " + etaSymbol + " [-]");
setPanelTitle(ax1, sprintf('A. Conditional HVI survival over (%s)', ...
    strjoin(data.NuisanceSymbols, ', ')));
colormap(ax1, parula(256));
survivalFloor = 1 / data.SampleCount;
clim(ax1, [log10(survivalFloor), 0]);
colorBar = colorbar(ax1);
colorBar.Ticks = log10([survivalFloor, 1e-3, 1e-2, 1e-1, 1]);
colorBar.TickLabels = ["<=1/2048", "1e-3", "1e-2", "1e-1", "1"];
colorBar.Label.String = 'Conditional exceedance probability';
colorBar.FontName = 'Times New Roman';
colorBar.Label.FontName = 'Times New Roman';
colorBar.TickLabelInterpreter = 'none';
colorBar.Label.Interpreter = 'none';
colorBar.Units = 'normalized';
colorBar.Position = [0.815, 0.720, 0.022, 0.200];
ax1.Position = axesPositions(1, :);

ax2 = axes(fig, 'Units', 'normalized', ...
    'Position', axesPositions(2, :), ...
    'PositionConstraint', 'innerposition');
hold(ax2, 'on');
quantile90 = positiveOnly(data.QuantilesNormalized(:, 2));
quantile99 = positiveOnly(data.QuantilesNormalized(:, 3));
if any(isfinite(quantile90))
    plot(ax2, data.InputPhysical, quantile90, ...
        'Color', colors.gold, 'LineWidth', 1.6, ...
        'DisplayName', '90th percentile');
end
if any(isfinite(quantile99))
    plot(ax2, data.InputPhysical, quantile99, ...
        'Color', colors.orange, 'LineWidth', 1.8, ...
        'DisplayName', '99th percentile');
end
plot(ax2, data.InputPhysical, positiveOnly(data.MeanNormalized), '--', ...
    'Color', colors.blue, 'LineWidth', 1.7, ...
    'DisplayName', 'Conditional mean');
plot(ax2, data.InputPhysical, positiveOnly(data.ProfileMaximum), ...
    'Color', [0.12, 0.12, 0.12], 'LineWidth', 2.0, ...
    'DisplayName', 'Sampled profile maximum');
scatter(ax2, data.SelectedInput, data.SelectedHviNormalized, 72, 'p', ...
    'MarkerFaceColor', colors.red, 'MarkerEdgeColor', 'white', ...
    'LineWidth', 0.8, 'DisplayName', 'Selected design');
hold(ax2, 'off');
setTimesStyle(ax2);
set(ax2, 'YScale', 'log', 'Box', 'off', 'XGrid', 'on', ...
    'YGrid', 'on', 'YMinorGrid', 'on', 'GridColor', colors.grid, ...
    'MinorGridColor', colors.grid, 'GridAlpha', 0.8, ...
    'MinorGridAlpha', 0.45, 'Layer', 'top');
plotSpan = data.InputPhysical(end) - data.InputPhysical(1);
plotLimits = [data.InputPhysical(1) - 0.015 * plotSpan, ...
    data.InputPhysical(end) + 0.015 * plotSpan];
xlim(ax2, plotLimits);
ylim(ax2, [1e-8, 1.15]);
xlabel(ax2, data.AxisLabel);
ylabel(ax2, 'Normalized HVI [-]');
setPanelTitle(ax2, 'B. Conditional quantiles and profile');
legend(ax2, 'Location', 'southwest', 'FontName', 'Times New Roman', ...
    'FontSize', 9, 'Box', 'off', 'Interpreter', 'none');
addPermanentZeroMarker(ax2, data, colors.grey);

ax3 = axes(fig, 'Units', 'normalized', ...
    'Position', axesPositions(3, :), ...
    'PositionConstraint', 'innerposition');
hold(ax3, 'on');
plot(ax3, data.InputPhysical, positiveOnly(data.PositiveFraction), ...
    'Color', colors.orange, 'LineWidth', 2.0, ...
    'DisplayName', sprintf('Pr[HVI > 0 | %s]', data.Symbol));
plot(ax3, data.InputPhysical, positiveOnly(data.MeanNormalized), '--', ...
    'Color', colors.blue, 'LineWidth', 1.8, ...
    'DisplayName', 'Mean HVI / global maximum HVI');
hold(ax3, 'off');
setTimesStyle(ax3);
set(ax3, 'YScale', 'log', 'Box', 'off', 'XGrid', 'on', ...
    'YGrid', 'on', 'YMinorGrid', 'on', 'GridColor', colors.grid, ...
    'MinorGridColor', colors.grid, 'GridAlpha', 0.8, ...
    'MinorGridAlpha', 0.45, 'Layer', 'top');
xlim(ax3, plotLimits);
ylim(ax3, [1e-8, 1]);
xlabel(ax3, data.AxisLabel);
ylabel(ax3, 'Conditional domain-volume statistic [-]');
setPanelTitle(ax3, 'C. Positive-HVI support and conditional mean');
legend(ax3, 'Location', 'best', 'FontName', 'Times New Roman', ...
    'FontSize', 9, 'Box', 'off', 'Interpreter', 'none');

annotation(fig, 'textbox', [0.025, 0.955, 0.950, 0.032], ...
    'String', sprintf(['Frozen Thompson-sampled HVI field versus %s ' ...
    '(iteration %d)'], data.DisplayName, data.Iteration), ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'FontName', 'Times New Roman', ...
    'FontSize', 12.5, 'FontWeight', 'bold', 'Interpreter', 'none');
nuisanceText = strjoin(data.NuisanceSymbols, ', ');
annotation(fig, 'textbox', [0.07, 0.055, 0.86, 0.055], ...
    'String', sprintf(['At every %s station, the same %d-point stratified ' ...
    'Latin hypercube samples the uniform nuisance volume over (%s). The curves and ' ...
    'survival statistics are conditional acquisition-field distributions, ' ...
    'not isolated one-variable sensitivities.'], data.Symbol, ...
    data.SampleCount, nuisanceText), 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontName', 'Times New Roman', 'FontSize', 9, ...
    'Color', colors.grey, 'Interpreter', 'none');
annotation(fig, 'textbox', [0.07, 0.012, 0.86, 0.032], ...
    'String', sprintf(['Source: source-sealed cTSEMO 0.2.1 WB150 ' ...
    'replicate 2, frozen iteration %d before evaluation %d.'], ...
    data.Iteration, data.TrainingCount + 1), 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontName', 'Times New Roman', 'FontSize', 8.5, ...
    'Color', colors.grey, 'Interpreter', 'none');
fig.PaperUnits = 'inches';
fig.PaperSize = [7.5, 10.2];
fig.PaperPosition = [0, 0, 7.5, 10.2];
fig.PaperPositionMode = 'manual';
print(fig, outputFile, '-dpdf', '-vector');
close(fig);
end

function setPanelTitle(ax, titleText)
titleHandle = title(ax, titleText, 'FontWeight', 'bold', ...
    'Interpreter', 'none');
titleHandle.Units = 'normalized';
titleHandle.Position = [0, 1.015, 0];
titleHandle.HorizontalAlignment = 'left';
titleHandle.VerticalAlignment = 'bottom';
end

function addPermanentZeroMarker(ax, data, color)
if ~isfinite(data.FirstPermanentZeroInput)
    return;
end
xline(ax, data.FirstPermanentZeroInput, ':', 'Color', color, ...
    'LineWidth', 1.1, 'HandleVisibility', 'off');
span = data.InputPhysical(end) - data.InputPhysical(1);
text(ax, data.FirstPermanentZeroInput + 0.025 * span, 3e-3, ...
    sprintf('All sampled HVI = 0 for %s >= %.4g', ...
    data.DisplayName, data.FirstPermanentZeroInput), ...
    'FontName', 'Times New Roman', 'FontSize', 8.5, ...
    'Color', color, 'Interpreter', 'none');
end

function quantiles = columnQuantiles(values, probabilities)
sortedValues = sort(values, 1);
sampleCount = size(sortedValues, 1);
quantiles = zeros(numel(probabilities), size(values, 2));
for probabilityIndex = 1:numel(probabilities)
    position = 1 + (sampleCount - 1) * probabilities(probabilityIndex);
    lowerIndex = floor(position);
    upperIndex = ceil(position);
    fraction = position - lowerIndex;
    quantiles(probabilityIndex, :) = ...
        (1 - fraction) .* sortedValues(lowerIndex, :) + ...
        fraction .* sortedValues(upperIndex, :);
end
end

function [lastPositiveInput, firstPermanentZeroInput] = ...
        supportCutoff(inputPhysical, values)
lastPositiveIndex = find(values > 0, 1, 'last');
if isempty(lastPositiveIndex)
    lastPositiveInput = NaN;
    firstPermanentZeroInput = inputPhysical(1);
    return;
end
lastPositiveInput = inputPhysical(lastPositiveIndex);
if lastPositiveIndex < numel(inputPhysical)
    firstPermanentZeroInput = inputPhysical(lastPositiveIndex + 1);
else
    firstPermanentZeroInput = NaN;
end
end

function values = positiveOnly(values)
values(values <= 0) = NaN;
end

function hvi = evaluateHvi(draws, xUnit, objectiveCenter, ...
        objectiveScale, feasibleObjectives, referencePoint)
yDraw = evaluateDraws(draws, xUnit);
yStandardized = (yDraw - objectiveCenter) ./ objectiveScale;
hvi = ctsemo.sampledHVI( ...
    yStandardized, feasibleObjectives, referencePoint);
end

function yDraw = evaluateDraws(draws, xUnit)
yDraw = zeros(size(xUnit, 1), 2);
for objectiveIndex = 1:2
    yDraw(:, objectiveIndex) = ctsemo.evaluateObjectiveTS( ...
        draws{objectiveIndex}, xUnit);
end
end

function design = latinHypercube(pointCount, dimension, seed)
previousState = rng;
stateCleanup = onCleanup(@() rng(previousState));
rng(seed, 'twister');
design = zeros(pointCount, dimension);
for dimensionIndex = 1:dimension
    strata = randperm(pointCount).';
    design(:, dimensionIndex) = ...
        (strata - rand(pointCount, 1)) ./ pointCount;
end
end

function value = empiricalQuantile(sample, probability)
sample = sort(sample(:));
position = 1 + probability * (numel(sample) - 1);
lower = floor(position);
upper = ceil(position);
fraction = position - lower;
value = sample(lower) + fraction * (sample(upper) - sample(lower));
end

function [standardizedY, center, scale] = standardizeObjectives(y)
center = mean(y, 1);
scale = std(y, 0, 1);
minimumScale = sqrt(eps) .* max(1, max(abs(y), [], 1));
invalidScale = ~isfinite(scale) | scale <= minimumScale;
scale(invalidScale) = 1;
standardizedY = (y - center) ./ scale;
end

function referencePoint = acquisitionReference(feasibleY)
lower = min(feasibleY, [], 1);
upper = max(feasibleY, [], 1);
span = upper - lower;
referencePoint = upper + max( ...
    0.1 .* span, 0.1 .* max(1, abs(upper)));
end

function buildHviProfiles(data, outputFile)
hvi = data(strcmp(data.Quantity, 'HVI_draw'), :);
assert(height(hvi) == 124, ...
    'Expected 31 profile stations for each of four inputs.');

fig = figure('Visible', 'off', 'Color', 'white', 'Units', 'inches', ...
    'Position', [0.5, 0.5, 7.4, 8.6]);
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, 'Source-sealed WB150 sampled-HVI profiles', ...
    'FontName', 'Times New Roman', 'FontSize', 13, ...
    'FontWeight', 'bold');

maxY = 1.05 * max(hvi.Q90);
axesHandles = gobjects(4, 1);
for inputIndex = 1:4
    rows = hvi(hvi.Input == inputIndex, :);
    rows = sortrows(rows, 'GridIndex');
    x = rows.InputPhysical;
    axesHandles(inputIndex) = nexttile(layout);
    ax = axesHandles(inputIndex);
    hold(ax, 'on');
    band = fill(ax, [x; flipud(x)], [rows.Q10; flipud(rows.Q90)], ...
        [0.78, 0.87, 0.94], 'EdgeColor', 'none', ...
        'FaceAlpha', 0.75);
    meanLine = plot(ax, x, rows.Mean, '-', 'Color', [0.05, 0.31, 0.55], ...
        'LineWidth', 1.7);
    medianLine = plot(ax, x, rows.Median, '-', ...
        'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.4);
    hold(ax, 'off');
    grid(ax, 'on');
    box(ax, 'on');
    pbaspect(ax, [1, 1, 1]);
    ylim(ax, [0, maxY]);
    xlabel(ax, sprintf('x_%d (native units)', inputIndex));
    ylabel(ax, 'Sampled HVI');
    title(ax, sprintf('Input x_%d', inputIndex), 'FontWeight', 'normal');
    setTimesStyle(ax);
end

legend(axesHandles(1), [band, meanLine, medianLine], ...
    {'10th-90th percentile', 'Mean', 'Median'}, ...
    'Location', 'northoutside', 'Orientation', 'horizontal', ...
    'FontName', 'Times New Roman', 'FontSize', 9);
exportgraphics(fig, outputFile, 'ContentType', 'vector');
close(fig);
end

function buildHviPairwiseSlices(data, outputFile)
pairs = [1, 2; 1, 3; 1, 4; 2, 3; 2, 4; 3, 4];
fig = figure('Visible', 'off', 'Color', 'white', 'Units', 'inches', ...
    'Position', [0.5, 0.5, 7.5, 10.2]);
layout = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, 'Source-sealed WB150 pairwise slices of sampled HVI', ...
    'FontName', 'Times New Roman', 'FontSize', 13, ...
    'FontWeight', 'bold');
axesHandles = gobjects(6, 1);
positiveLogHvi = log10(data.HVI_draw(data.HVI_draw > 1.0e-12));
colorLimits = [floor(2 * min(positiveLogHvi)) / 2, ...
    ceil(2 * max(positiveLogHvi)) / 2];

for pairIndex = 1:size(pairs, 1)
    inputA = pairs(pairIndex, 1);
    inputB = pairs(pairIndex, 2);
    rows = data(data.InputA == inputA & data.InputB == inputB, :);
    assert(height(rows) == 625, 'Expected a 25-by-25 pairwise slice.');

    xName = sprintf('x%d', inputA);
    yName = sprintf('x%d', inputB);
    xValues = unique(rows.(xName), 'sorted');
    yValues = unique(rows.(yName), 'sorted');
    z = nan(numel(yValues), numel(xValues));
    for rowIndex = 1:height(rows)
        [~, ix] = min(abs(xValues - rows.(xName)(rowIndex)));
        [~, iy] = min(abs(yValues - rows.(yName)(rowIndex)));
        z(iy, ix) = log10(rows.HVI_draw(rowIndex) + 1.0e-12);
    end

    axesHandles(pairIndex) = nexttile(layout);
    ax = axesHandles(pairIndex);
    imagesc(ax, xValues, yValues, z);
    axis(ax, 'xy');
    pbaspect(ax, [1, 1, 1]);
    clim(ax, colorLimits);
    box(ax, 'on');
    xlabel(ax, sprintf('x_%d', inputA));
    ylabel(ax, sprintf('x_%d', inputB));
    title(ax, sprintf('x_%d and x_%d', inputA, inputB), ...
        'FontWeight', 'normal');
    setTimesStyle(ax);
end

colormap(fig, parula(256));
colorBar = colorbar(axesHandles(end), 'southoutside');
colorBar.Layout.Tile = 'south';
colorBar.Label.String = 'log_{10}(sampled HVI + 10^{-12})';
colorBar.FontName = 'Times New Roman';
colorBar.FontSize = 9;
exportgraphics(fig, outputFile, 'ContentType', 'vector');
close(fig);
end

function finalFramePdf = buildParetoEvolution(data, outputDirectory)
assert(height(data) == 150, 'WB150 must contain 150 evaluations.');
assert(sum(data.IsInitial) == 20, 'WB150 must contain 20 initial designs.');
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

y = [data.f1, data.f2];
isFeasible = logical(data.IsFeasible);
fullXLim = paddedLimits(y(:, 1), 0.04, true);
fullYLim = paddedLogLimits(y(:, 2), 0.08);
finalPareto = paretoMask2D(y, isFeasible);
assert(sum(finalPareto) == 16, ...
    'Representative source-sealed WB150 run must end with 16 Pareto points.');
zoomXLim = paddedLimits(y(finalPareto, 1), 0.10, true);
zoomYLim = paddedLimits(y(finalPareto, 2), 0.12, true);

fig = figure('Visible', 'off', 'Color', 'white', 'Units', 'inches', ...
    'Position', [0.25, 0.25, 8.27, 11.69]);
set(fig, 'PaperUnits', 'inches', 'PaperSize', [8.2677, 11.6929], ...
    'PaperPosition', [0, 0, 8.2677, 11.6929], ...
    'PaperPositionMode', 'manual');
for iteration = 1:130
    evaluation = 20 + iteration;
    prefix = 1:evaluation;
    currentFeasible = isFeasible(prefix);
    currentPareto = paretoMask2D(y(prefix, :), currentFeasible);

    clf(fig);
    layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', ...
        'Padding', 'compact');
    layout.OuterPosition = [0.04, 0.075, 0.92, 0.88];
    title(layout, {'Source-sealed WB150 Pareto-front evolution', ...
        sprintf('Iteration %d of 130 (evaluation %d of 150)', ...
        iteration, evaluation)}, ...
        'FontName', 'Times New Roman', 'FontSize', 14, ...
        'FontWeight', 'bold');

    topAx = nexttile(layout);
    drawParetoPanel(topAx, y(prefix, :), currentFeasible, currentPareto, ...
        evaluation, fullXLim, fullYLim, true, 'Complete objective space');

    bottomAx = nexttile(layout);
    drawParetoPanel(bottomAx, y(prefix, :), currentFeasible, currentPareto, ...
        evaluation, zoomXLim, zoomYLim, false, 'Fixed Pareto-region view');
    legend(bottomAx, {'Infeasible', 'Feasible, dominated', ...
        'Current feasible Pareto front', 'Newest evaluation'}, ...
        'Location', 'northoutside', 'Orientation', 'horizontal', ...
        'NumColumns', 2, 'FontName', 'Times New Roman', 'FontSize', 9);

    stateText = sprintf(['Evaluated: %d   Feasible: %d   ' ...
        'Pareto points: %d   Newest point: %s'], ...
        evaluation, sum(currentFeasible), sum(currentPareto), ...
        feasibilityWord(currentFeasible(end)));
    annotation(fig, 'textbox', [0.08, 0.032, 0.84, 0.022], ...
        'String', stateText, 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
        'FontSize', 9);
    annotation(fig, 'textbox', [0.08, 0.013, 0.84, 0.018], ...
        'String', ['Source: cTSEMO 0.2.1 welded-beam replicate 2; fronts ' ...
        'recomputed from feasible observations.'], 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'FontName', 'Times New Roman', ...
        'FontSize', 8, 'Color', [0.35, 0.35, 0.35]);

    drawnow;
    outputFile = fullfile(outputDirectory, ...
        sprintf('page_%03d.pdf', iteration));
    print(fig, outputFile, '-dpdf', '-vector');
end
close(fig);
finalFramePdf = fullfile(outputDirectory, 'page_130.pdf');
end

function drawParetoPanel(ax, y, isFeasible, isPareto, newestIndex, ...
    xLimits, yLimits, useLogScale, panelTitle)
hold(ax, 'on');
infeasible = ~isFeasible;
dominated = isFeasible & ~isPareto;
scatter(ax, y(infeasible, 1), y(infeasible, 2), 28, 'x', ...
    'MarkerEdgeColor', [0.55, 0.55, 0.55], 'LineWidth', 1.0);
scatter(ax, y(dominated, 1), y(dominated, 2), 30, 'o', ...
    'MarkerEdgeColor', [0.25, 0.48, 0.68], ...
    'MarkerFaceColor', 'white', 'LineWidth', 0.9);

paretoY = y(isPareto, :);
[~, order] = sort(paretoY(:, 1), 'ascend');
paretoY = paretoY(order, :);
plot(ax, paretoY(:, 1), paretoY(:, 2), '-o', ...
    'Color', [0.00, 0.35, 0.65], 'MarkerFaceColor', [0.00, 0.35, 0.65], ...
    'MarkerEdgeColor', 'white', 'LineWidth', 1.8, 'MarkerSize', 5.5);
scatter(ax, y(newestIndex, 1), y(newestIndex, 2), 68, 'd', ...
    'MarkerEdgeColor', [0.75, 0.25, 0.02], ...
    'MarkerFaceColor', [0.95, 0.45, 0.08], 'LineWidth', 1.0);

hold(ax, 'off');
box(ax, 'on');
grid(ax, 'on');
xlim(ax, xLimits);
ylim(ax, yLimits);
if useLogScale
    set(ax, 'YScale', 'log');
else
    set(ax, 'YScale', 'linear');
end
xlabel(ax, 'Objective f_1 (benchmark cost index)');
ylabel(ax, 'Objective f_2 (benchmark deflection index)');
title(ax, panelTitle, 'FontWeight', 'normal');
setTimesStyle(ax);
end

function mask = paretoMask2D(y, isFeasible)
mask = false(size(isFeasible));
indices = find(isFeasible & all(isfinite(y), 2));
for ii = 1:numel(indices)
    i = indices(ii);
    others = indices(indices ~= i);
    dominates = all(y(others, :) <= y(i, :), 2) & ...
        any(y(others, :) < y(i, :), 2);
    mask(i) = ~any(dominates);
end
end

function limits = paddedLimits(values, fraction, includeZero)
values = values(isfinite(values));
low = min(values);
high = max(values);
span = max(high - low, eps(max(abs(values))));
limits = [low - fraction * span, high + fraction * span];
if includeZero && low >= 0
    limits(1) = 0;
end
end

function limits = paddedLogLimits(values, decades)
values = values(isfinite(values) & values > 0);
limits = 10 .^ ([log10(min(values)), log10(max(values))] + [-decades, decades]);
end

function word = feasibilityWord(isFeasible)
if isFeasible
    word = 'feasible';
else
    word = 'infeasible';
end
end

function setTimesStyle(ax)
set(ax, 'FontName', 'Times New Roman', 'FontSize', 10, ...
    'LineWidth', 0.8, 'TickDir', 'out', ...
    'TickLabelInterpreter', 'none');
ax.XLabel.FontName = 'Times New Roman';
ax.YLabel.FontName = 'Times New Roman';
ax.Title.FontName = 'Times New Roman';
ax.XLabel.Interpreter = 'none';
ax.YLabel.Interpreter = 'none';
ax.Title.Interpreter = 'none';
end
