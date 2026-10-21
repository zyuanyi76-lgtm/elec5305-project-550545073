
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Alpha-Beta Parameter Sweep
% Development set only
% 5 alpha values x 4 beta values = 20 configurations
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

%% Fixed processing settings

prefixDuration = 0.5;
winLength = 512;
hopSize = 256;
nfft = 512;

%% Parameter grid

alphaGrid = [1.0, 1.5, 2.0, 2.5, 3.0];

betaGrid = [0.00, 0.01, 0.03, 0.05];

numAlpha = length(alphaGrid);
numBeta = length(betaGrid);

%% Load development file list

files = dir(fullfile(devRoot, "*.mat"));

numFiles = length(files);
numConfigurations = numAlpha * numBeta;
totalRuns = numFiles * numConfigurations;

if numFiles ~= 24
    error("Expected 24 development mixtures, found %d.", ...
        numFiles);
end

fprintf("===== PARAMETER SWEEP =====\n");
fprintf("Development mixtures: %d\n", numFiles);
fprintf("Parameter configurations: %d\n", ...
    numConfigurations);
fprintf("Total evaluations: %d\n\n", totalRuns);

%% Preallocate results

fileNames = strings(totalRuns, 1);
noiseTypes = strings(totalRuns, 1);

targetSNRs = zeros(totalRuns, 1);
alphaValues = zeros(totalRuns, 1);
betaValues = zeros(totalRuns, 1);

inputSNRs = zeros(totalRuns, 1);
outputSNRs = zeros(totalRuns, 1);
improvements = zeros(totalRuns, 1);

rowIndex = 0;

tic;

%% =========================================================
% Evaluate all development mixtures
%% =========================================================

for f = 1:numFiles

    data = load(fullfile(files(f).folder, files(f).name));

    if string(data.splitName) ~= "dev"
        error("Non-development file detected.");
    end

    fullNoisy = data.fullNoisy;
    clean = data.cleanReference(:);
    noise = data.noiseReference(:);
    fs = data.fs;

    prefixSamples = round(prefixDuration * fs);

    inputSNR = 10 * log10( ...
        sum(clean.^2) / (sum(noise.^2) + eps));

    for a = 1:numAlpha

        alpha = alphaGrid(a);

        for b = 1:numBeta

            beta = betaGrid(b);

            %% Run modified spectral subtraction

            result = modified_spectral_subtraction( ...
                fullNoisy, fs, prefixDuration, ...
                winLength, hopSize, nfft, ...
                alpha, beta);

            %% Extract enhanced speech

            enhanced = result.enhancedFull( ...
                prefixSamples+1:end);

            enhanced = enhanced(:);

            if length(enhanced) ~= length(clean)
                error("Enhanced signal length mismatch.");
            end

            %% Reference-based output SNR

            errorSignal = enhanced - clean;

            outputSNR = 10 * log10( ...
                sum(clean.^2) / ...
                (sum(errorSignal.^2) + eps));

            snrImprovement = outputSNR - inputSNR;

            %% Store results

            rowIndex = rowIndex + 1;

            fileNames(rowIndex) = string(files(f).name);
            noiseTypes(rowIndex) = string(data.noiseType);

            targetSNRs(rowIndex) = data.targetSNR;

            alphaValues(rowIndex) = alpha;
            betaValues(rowIndex) = beta;

            inputSNRs(rowIndex) = inputSNR;
            outputSNRs(rowIndex) = outputSNR;
            improvements(rowIndex) = snrImprovement;

        end
    end

    fprintf("Processed %2d/%2d: %s\n", ...
        f, numFiles, files(f).name);

end

elapsedTime = toc;

%% =========================================================
% Save all individual results
%% =========================================================

detailedResults = table( ...
    fileNames, noiseTypes, targetSNRs, ...
    alphaValues, betaValues, ...
    inputSNRs, outputSNRs, improvements, ...
    'VariableNames', { ...
    'filename', 'noise_type', 'target_snr_db', ...
    'alpha', 'beta', ...
    'input_snr_db', 'output_snr_db', ...
    'snr_improvement_db'});

writetable(detailedResults, ...
    fullfile(metricsRoot, ...
    "alpha_beta_dev_detailed.csv"));

%% =========================================================
% Compute group-average results
%% =========================================================

meanAll = zeros(numAlpha, numBeta);
meanWhite = zeros(numAlpha, numBeta);
meanEnvironmental = zeros(numAlpha, numBeta);

for a = 1:numAlpha

    for b = 1:numBeta

        selected = ...
            alphaValues == alphaGrid(a) & ...
            betaValues == betaGrid(b);

        whiteSelected = selected & ...
            noiseTypes == "white";

        envSelected = selected & ...
            noiseTypes == "environmental";

        meanAll(a,b) = mean(improvements(selected));

        meanWhite(a,b) = mean(improvements(whiteSelected));

        meanEnvironmental(a,b) = ...
            mean(improvements(envSelected));

    end
end

%% Create summary table

numRows = numConfigurations;

summaryAlpha = zeros(numRows,1);
summaryBeta = zeros(numRows,1);

summaryAll = zeros(numRows,1);
summaryWhite = zeros(numRows,1);
summaryEnvironmental = zeros(numRows,1);

k = 0;

for a = 1:numAlpha
    for b = 1:numBeta

        k = k + 1;

        summaryAlpha(k) = alphaGrid(a);
        summaryBeta(k) = betaGrid(b);

        summaryAll(k) = meanAll(a,b);
        summaryWhite(k) = meanWhite(a,b);
        summaryEnvironmental(k) = ...
            meanEnvironmental(a,b);

    end
end

summaryTable = table( ...
    summaryAlpha, summaryBeta, ...
    summaryAll, summaryWhite, summaryEnvironmental, ...
    'VariableNames', { ...
    'alpha', 'beta', ...
    'mean_snr_improvement_db', ...
    'white_snr_improvement_db', ...
    'environmental_snr_improvement_db'});

writetable(summaryTable, ...
    fullfile(metricsRoot, ...
    "alpha_beta_dev_summary.csv"));

%% =========================================================
% Print descriptive results
%% =========================================================

fprintf("\n===== SWEEP SUMMARY =====\n");

fprintf("Total evaluations: %d\n", rowIndex);
fprintf("Elapsed time: %.2f seconds\n", elapsedTime);

fprintf("\nMean SNR improvement for each configuration:\n");

disp(summaryTable);

baselineMean = meanAll(1,1);

fprintf("Basic baseline mean improvement: %.3f dB\n", ...
    baselineMean);

[maxMean, bestIndex] = max(summaryAll);

fprintf("\nHighest development mean SNR improvement:\n");
fprintf("Alpha: %.2f\n", summaryAlpha(bestIndex));
fprintf("Beta: %.3f\n", summaryBeta(bestIndex));
fprintf("Mean SNR improvement: %.3f dB\n", maxMean);

fprintf("\nNote: SNR alone is not used for final selection.\n");
fprintf("STOI and distortion analysis are still required.\n");

%% =========================================================
% Plot heatmaps
%% =========================================================

figure('Position', [100, 150, 1350, 420]);

tiledlayout(1,3, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

plotTitles = { ...
    "All Development Mixtures", ...
    "White Noise", ...
    "Environmental Noise"};

plotData = {meanAll, meanWhite, meanEnvironmental};

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

    colorbar;
    colormap(parula);

    for a = 1:numAlpha
        for b = 1:numBeta

            text(b, a, ...
                sprintf("%.2f", plotData{p}(a,b)), ...
                'HorizontalAlignment', 'center', ...
                'Color', 'black', ...
                'FontSize', 9);

        end
    end

end

sgtitle("Development Set - Mean SNR Improvement (dB)");

%% Save figure

exportgraphics(gcf, ...
    fullfile(figureRoot, ...
    "alpha_beta_snr_heatmaps.png"), ...
    'Resolution', 200);

fprintf("\n===== OUTPUT FILES =====\n");

fprintf("alpha_beta_dev_detailed.csv\n");
fprintf("alpha_beta_dev_summary.csv\n");
fprintf("alpha_beta_snr_heatmaps.png\n");

fprintf("\nDone.\n");
