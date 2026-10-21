
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - STOI Evaluation
% Development set only
% 24 mixtures x 20 parameter combinations
%% =========================================================

%% Project paths

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

enhancementRoot = fullfile( ...
    projectRoot, "code", "enhancement");

devRoot = fullfile( ...
    projectRoot, "data", "mixtures", "dev");

figureRoot = fullfile( ...
    projectRoot, "results", "figures");

metricsRoot = fullfile( ...
    projectRoot, "results", "metrics");

addpath(enhancementRoot);

if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

if ~exist(metricsRoot, "dir")
    mkdir(metricsRoot);
end

%% Verify STOI availability

if exist("stoi", "file") ~= 2
    error("STOI function is unavailable.");
end

%% Fixed processing parameters

prefixDuration = 0.5;
winLength = 512;
hopSize = 256;
nfft = 512;

%% Alpha-beta grid

alphaGrid = [1.0, 1.5, 2.0, 2.5, 3.0];
betaGrid = [0.00, 0.01, 0.03, 0.05];

numAlpha = numel(alphaGrid);
numBeta = numel(betaGrid);

%% Load development mixtures

files = dir(fullfile(devRoot, "*.mat"));

numFiles = numel(files);
numConfigurations = numAlpha * numBeta;
totalRuns = numFiles * numConfigurations;

if numFiles ~= 24
    error("Expected 24 development mixtures.");
end

fprintf("===== STOI EVALUATION =====\n");
fprintf("Development mixtures: %d\n", numFiles);
fprintf("Parameter configurations: %d\n", numConfigurations);
fprintf("Total evaluations: %d\n\n", totalRuns);

%% Preallocate results

fileNames = strings(totalRuns, 1);
noiseTypes = strings(totalRuns, 1);

targetSNRs = zeros(totalRuns, 1);
alphaValues = zeros(totalRuns, 1);
betaValues = zeros(totalRuns, 1);

inputSTOIs = zeros(totalRuns, 1);
outputSTOIs = zeros(totalRuns, 1);
stoiImprovements = zeros(totalRuns, 1);

snrImprovements = zeros(totalRuns, 1);

rowIndex = 0;

tic;

%% =========================================================
% Process development mixtures
%% =========================================================

for f = 1:numFiles

    data = load(fullfile( ...
        files(f).folder, files(f).name));

    if string(data.splitName) ~= "dev"
        error("Non-development mixture detected.");
    end

    fullNoisy = double(data.fullNoisy(:));
    clean = double(data.cleanReference(:));
    noise = double(data.noiseReference(:));
    fs = data.fs;

    if fs ~= 16000
        error("Expected a 16 kHz sample rate.");
    end

    noisy = clean + noise;

    prefixSamples = round(prefixDuration * fs);

    %% Input metrics

    inputSTOI = stoi(noisy, clean, fs);

    inputSNR = 10*log10( ...
        sum(clean.^2) / ...
        (sum(noise.^2) + eps));

    %% Sweep alpha-beta values

    for a = 1:numAlpha

        alpha = alphaGrid(a);

        for b = 1:numBeta

            beta = betaGrid(b);

            %% Run enhancement

            result = modified_spectral_subtraction( ...
                fullNoisy, fs, prefixDuration, ...
                winLength, hopSize, nfft, ...
                alpha, beta);

            %% Remove noise-only prefix

            enhanced = result.enhancedFull( ...
                prefixSamples+1:end);

            enhanced = double(enhanced(:));

            if numel(enhanced) ~= numel(clean)
                error("Enhanced signal length mismatch.");
            end

            %% STOI calculation

            outputSTOI = stoi(enhanced, clean, fs);

            stoiGain = outputSTOI - inputSTOI;

            if ~isfinite(outputSTOI)
                error("Invalid STOI score detected.");
            end

            %% SNR calculation

            errorSignal = enhanced - clean;

            outputSNR = 10*log10( ...
                sum(clean.^2) / ...
                (sum(errorSignal.^2) + eps));

            snrGain = outputSNR - inputSNR;

            %% Store results

            rowIndex = rowIndex + 1;

            fileNames(rowIndex) = string(files(f).name);
            noiseTypes(rowIndex) = string(data.noiseType);

            targetSNRs(rowIndex) = data.targetSNR;

            alphaValues(rowIndex) = alpha;
            betaValues(rowIndex) = beta;

            inputSTOIs(rowIndex) = inputSTOI;
            outputSTOIs(rowIndex) = outputSTOI;

            stoiImprovements(rowIndex) = stoiGain;
            snrImprovements(rowIndex) = snrGain;

        end
    end

    fprintf("Processed %2d/%2d: %s\n", ...
        f, numFiles, files(f).name);

end

elapsedTime = toc;

%% =========================================================
% Save detailed results
%% =========================================================

detailedResults = table( ...
    fileNames, noiseTypes, targetSNRs, ...
    alphaValues, betaValues, ...
    inputSTOIs, outputSTOIs, ...
    stoiImprovements, snrImprovements, ...
    'VariableNames', { ...
    'filename', 'noise_type', 'target_snr_db', ...
    'alpha', 'beta', ...
    'input_stoi', 'output_stoi', ...
    'stoi_improvement', 'snr_improvement_db'});

writetable(detailedResults, ...
    fullfile(metricsRoot, "stoi_dev_detailed.csv"));

%% =========================================================
% Calculate average results
%% =========================================================

meanAll = zeros(numAlpha, numBeta);
meanWhite = zeros(numAlpha, numBeta);
meanEnvironmental = zeros(numAlpha, numBeta);

meanSTOIGain = zeros(numAlpha, numBeta);
meanSNRGain = zeros(numAlpha, numBeta);

for a = 1:numAlpha

    for b = 1:numBeta

        selected = ...
            alphaValues == alphaGrid(a) & ...
            betaValues == betaGrid(b);

        whiteSelected = selected & ...
            noiseTypes == "white";

        envSelected = selected & ...
            noiseTypes == "environmental";

        meanAll(a,b) = mean(outputSTOIs(selected));

        meanWhite(a,b) = ...
            mean(outputSTOIs(whiteSelected));

        meanEnvironmental(a,b) = ...
            mean(outputSTOIs(envSelected));

        meanSTOIGain(a,b) = ...
            mean(stoiImprovements(selected));

        meanSNRGain(a,b) = ...
            mean(snrImprovements(selected));

    end
end

%% Summary table

numRows = numConfigurations;

summaryAlpha = zeros(numRows,1);
summaryBeta = zeros(numRows,1);

summarySTOI = zeros(numRows,1);
summarySTOIGain = zeros(numRows,1);
summarySNRGain = zeros(numRows,1);

summaryWhite = zeros(numRows,1);
summaryEnvironmental = zeros(numRows,1);

k = 0;

for a = 1:numAlpha

    for b = 1:numBeta

        k = k + 1;

        summaryAlpha(k) = alphaGrid(a);
        summaryBeta(k) = betaGrid(b);

        summarySTOI(k) = meanAll(a,b);

        summarySTOIGain(k) = meanSTOIGain(a,b);

        summarySNRGain(k) = meanSNRGain(a,b);

        summaryWhite(k) = meanWhite(a,b);
        summaryEnvironmental(k) = ...
            meanEnvironmental(a,b);

    end
end

summaryTable = table( ...
    summaryAlpha, summaryBeta, ...
    summarySTOI, summarySTOIGain, ...
    summarySNRGain, ...
    summaryWhite, summaryEnvironmental, ...
    'VariableNames', { ...
    'alpha', 'beta', ...
    'mean_output_stoi', ...
    'mean_stoi_improvement', ...
    'mean_snr_improvement_db', ...
    'white_output_stoi', ...
    'environmental_output_stoi'});

writetable(summaryTable, ...
    fullfile(metricsRoot, "stoi_dev_summary.csv"));

%% =========================================================
% Print results
%% =========================================================

fprintf("\n===== STOI SUMMARY =====\n");

fprintf("Total evaluations: %d\n", rowIndex);
fprintf("Elapsed time: %.2f seconds\n", elapsedTime);

fprintf("\nParameter summary:\n");

disp(summaryTable);

fprintf("\n===== BASIC BASELINE =====\n");

fprintf("Alpha: 1.00, Beta: 0.000\n");

fprintf("Mean output STOI: %.4f\n", ...
    meanAll(1,1));

fprintf("Mean STOI improvement: %.4f\n", ...
    meanSTOIGain(1,1));

fprintf("Mean SNR improvement: %.4f dB\n", ...
    meanSNRGain(1,1));

%% Highest development STOI

[bestSTOI, bestIndex] = max(summarySTOI);

fprintf("\n===== HIGHEST DEVELOPMENT STOI =====\n");

fprintf("Alpha: %.2f\n", summaryAlpha(bestIndex));
fprintf("Beta: %.3f\n", summaryBeta(bestIndex));

fprintf("Mean output STOI: %.4f\n", bestSTOI);

fprintf("Mean STOI improvement: %.4f\n", ...
    summarySTOIGain(bestIndex));

fprintf("Mean SNR improvement: %.4f dB\n", ...
    summarySNRGain(bestIndex));

fprintf("\nFinal parameters have not been selected.\n");

%% =========================================================
% Plot STOI heatmaps
%% =========================================================

figure('Position', [100, 150, 1350, 430]);

tiledlayout(1,3, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

plotTitles = { ...
    "All Development Mixtures", ...
    "White Noise", ...
    "Environmental Noise"};

plotData = {meanAll, meanWhite, meanEnvironmental};

globalMin = min([meanAll(:); meanWhite(:); ...
    meanEnvironmental(:)]);

globalMax = max([meanAll(:); meanWhite(:); ...
    meanEnvironmental(:)]);

for p = 1:3

    nexttile;

    imagesc(plotData{p});

    set(gca, 'YDir', 'normal');

    xticks(1:numBeta);
    xticklabels(string(betaGrid));

    yticks(1:numAlpha);
    yticklabels(string(alphaGrid));

    xlabel("Beta (Spectral Floor)");
    ylabel("Alpha (Over-subtraction)");

    title(plotTitles{p});

    clim([globalMin-0.001, globalMax+0.001]);

    colormap(parula);

    cb = colorbar;
    cb.Label.String = "Mean Output STOI";

    for a = 1:numAlpha

        for b = 1:numBeta

            value = plotData{p}(a,b);

            if value < (globalMin+globalMax)/2
                labelColor = 'white';
            else
                labelColor = 'black';
            end

            text(b, a, sprintf("%.3f", value), ...
                'HorizontalAlignment', 'center', ...
                'Color', labelColor, ...
                'FontSize', 9);

        end
    end
end

sgtitle("Development Set - Mean Output STOI");

exportgraphics(gcf, ...
    fullfile(figureRoot, "alpha_beta_stoi_heatmaps.png"), ...
    'Resolution', 200);

%% =========================================================
% Plot SNR-STOI trade-off
%% =========================================================

figure('Position', [180, 150, 850, 560]);

scatter( ...
    summarySNRGain, summarySTOI, ...
    90, summaryAlpha, 'filled');

hold on;

plot(summarySNRGain(1), summarySTOI(1), ...
    'kp', 'MarkerSize', 15, ...
    'LineWidth', 1.5);

plot(summarySNRGain(bestIndex), ...
    summarySTOI(bestIndex), ...
    'ks', 'MarkerSize', 13, ...
    'LineWidth', 1.5);

xlabel("Mean SNR Improvement (dB)");
ylabel("Mean Output STOI");

title("Development Set - SNR versus STOI");

grid on;

cb = colorbar;
cb.Label.String = "Alpha";

legend( ...
    "Parameter Configurations", ...
    "Basic Baseline", ...
    "Highest STOI", ...
    'Location', 'best');

exportgraphics(gcf, ...
    fullfile(figureRoot, "snr_stoi_tradeoff.png"), ...
    'Resolution', 200);

%% Final output

fprintf("\n===== OUTPUT FILES =====\n");

fprintf("stoi_dev_detailed.csv\n");
fprintf("stoi_dev_summary.csv\n");
fprintf("alpha_beta_stoi_heatmaps.png\n");
fprintf("snr_stoi_tradeoff.png\n");

fprintf("\nDone.\n");
