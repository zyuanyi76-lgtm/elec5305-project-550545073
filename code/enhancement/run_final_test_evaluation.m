
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Held-Out Test Evaluation
% Frozen development-selected configurations
% 48 test mixtures x 4 configurations = 192 evaluations
%% =========================================================

%% Project paths

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

addpath(fullfile(projectRoot, "code", "enhancement"));

testRoot = fullfile(projectRoot, ...
    "data", "mixtures", "test");

metricsRoot = fullfile(projectRoot, ...
    "results", "metrics");

figureRoot = fullfile(projectRoot, ...
    "results", "figures");

if ~exist(metricsRoot, "dir")
    mkdir(metricsRoot);
end

if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

%% Fixed STFT parameters

prefixDuration = 0.5;
winLength = 512;
hopSize = 256;
nfft = 512;

%% Frozen configurations

methodNames = [
    "Basic"
    "SNR_focused"
    "STOI_focused"
    "Aggressive_diagnostic"
];

alphaSet = [1.0; 1.5; 1.0; 3.0];
betaSet = [0.00; 0.05; 0.05; 0.03];

numMethods = numel(methodNames);

%% Load test mixtures

files = dir(fullfile(testRoot, "*.mat"));

numFiles = numel(files);

if numFiles ~= 48
    error("Expected 48 test mixtures, found %d.", numFiles);
end

totalRuns = numFiles * numMethods;

fprintf("===== HELD-OUT TEST EVALUATION =====\n");
fprintf("Test mixtures: %d\n", numFiles);
fprintf("Fixed configurations: %d\n", numMethods);
fprintf("Total evaluations: %d\n\n", totalRuns);

%% Preallocate

fileCol = strings(totalRuns,1);
speakerCol = strings(totalRuns,1);
noiseCol = strings(totalRuns,1);
methodCol = strings(totalRuns,1);

targetCol = zeros(totalRuns,1);
alphaCol = zeros(totalRuns,1);
betaCol = zeros(totalRuns,1);

inputSnrCol = zeros(totalRuns,1);
outputSnrCol = zeros(totalRuns,1);
snrGainCol = zeros(totalRuns,1);

inputStoiCol = zeros(totalRuns,1);
outputStoiCol = zeros(totalRuns,1);
stoiGainCol = zeros(totalRuns,1);

rowIndex = 0;

tic;

%% =========================================================
% Evaluate the entire held-out test set
%% =========================================================

for f = 1:numFiles

    data = load(fullfile( ...
        files(f).folder, files(f).name));

    if string(data.splitName) ~= "test"
        error("Development data detected in test folder.");
    end

    fs = data.fs;

    if fs ~= 16000
        error("Expected 16 kHz audio.");
    end

    clean = double(data.cleanReference(:));
    noise = double(data.noiseReference(:));
    fullNoisy = double(data.fullNoisy(:));

    prefixSamples = round(prefixDuration * fs);

    noisy = clean + noise;

    if numel(fullNoisy) ~= prefixSamples + numel(clean)
        error("Unexpected mixture length.");
    end

    %% Input metrics

    inputSNR = 10*log10( ...
        sum(clean.^2) / (sum(noise.^2) + eps));

    inputSTOI = stoi(noisy, clean, fs);

    %% Evaluate frozen configurations

    for m = 1:numMethods

        alpha = alphaSet(m);
        beta = betaSet(m);

        result = modified_spectral_subtraction( ...
            fullNoisy, fs, prefixDuration, ...
            winLength, hopSize, nfft, ...
            alpha, beta);

        enhanced = double( ...
            result.enhancedFull(prefixSamples+1:end));

        enhanced = enhanced(:);

        if numel(enhanced) ~= numel(clean)
            error("Enhanced signal length mismatch.");
        end

        %% Reference-based output SNR

        errorSignal = enhanced - clean;

        outputSNR = 10*log10( ...
            sum(clean.^2) / ...
            (sum(errorSignal.^2) + eps));

        snrGain = outputSNR - inputSNR;

        %% STOI

        outputSTOI = stoi(enhanced, clean, fs);
        stoiGain = outputSTOI - inputSTOI;

        if ~all(isfinite([outputSNR, outputSTOI]))
            error("Invalid evaluation metric.");
        end

        %% Store measurements

        rowIndex = rowIndex + 1;

        fileCol(rowIndex) = string(files(f).name);
        speakerCol(rowIndex) = string(data.speakerID);
        noiseCol(rowIndex) = string(data.noiseType);
        methodCol(rowIndex) = methodNames(m);

        targetCol(rowIndex) = data.targetSNR;
        alphaCol(rowIndex) = alpha;
        betaCol(rowIndex) = beta;

        inputSnrCol(rowIndex) = inputSNR;
        outputSnrCol(rowIndex) = outputSNR;
        snrGainCol(rowIndex) = snrGain;

        inputStoiCol(rowIndex) = inputSTOI;
        outputStoiCol(rowIndex) = outputSTOI;
        stoiGainCol(rowIndex) = stoiGain;

    end

    fprintf("Processed %2d/%2d: %s\n", ...
        f, numFiles, files(f).name);

end

elapsedTime = toc;

%% =========================================================
% Save detailed results
%% =========================================================

detailedTable = table( ...
    fileCol, speakerCol, noiseCol, methodCol, ...
    targetCol, alphaCol, betaCol, ...
    inputSnrCol, outputSnrCol, snrGainCol, ...
    inputStoiCol, outputStoiCol, stoiGainCol, ...
    'VariableNames', { ...
    'filename', 'speaker', 'noise_type', 'method', ...
    'target_snr_db', 'alpha', 'beta', ...
    'input_snr_db', 'output_snr_db', ...
    'snr_improvement_db', ...
    'input_stoi', 'output_stoi', ...
    'stoi_improvement'});

writetable(detailedTable, fullfile( ...
    metricsRoot, "test_detailed_metrics.csv"));

%% =========================================================
% Overall summary by method
%% =========================================================

meanSNR = zeros(numMethods,1);
meanSTOI = zeros(numMethods,1);
meanSTOIGain = zeros(numMethods,1);
stdSNR = zeros(numMethods,1);
stdSTOI = zeros(numMethods,1);

for m = 1:numMethods

    selected = methodCol == methodNames(m);

    meanSNR(m) = mean(snrGainCol(selected));
    meanSTOI(m) = mean(outputStoiCol(selected));
    meanSTOIGain(m) = mean(stoiGainCol(selected));

    stdSNR(m) = std(snrGainCol(selected));
    stdSTOI(m) = std(outputStoiCol(selected));

end

overallTable = table( ...
    methodNames, alphaSet, betaSet, ...
    meanSNR, stdSNR, meanSTOI, stdSTOI, ...
    meanSTOIGain, ...
    'VariableNames', { ...
    'method', 'alpha', 'beta', ...
    'mean_snr_improvement_db', ...
    'std_snr_improvement_db', ...
    'mean_output_stoi', ...
    'std_output_stoi', ...
    'mean_stoi_improvement'});

writetable(overallTable, fullfile( ...
    metricsRoot, "test_overall_summary.csv"));

%% =========================================================
% Results by noise type and input SNR
%% =========================================================

noiseTypes = ["white"; "environmental"];
snrLevels = [0; 5; 10];

conditionMethods = strings(24,1);
conditionNoise = strings(24,1);
conditionTarget = zeros(24,1);

conditionCount = zeros(24,1);
conditionSNR = zeros(24,1);
conditionSTOI = zeros(24,1);

k = 0;

for m = 1:numMethods

    for n = 1:numel(noiseTypes)

        for s = 1:numel(snrLevels)

            selected = ...
                methodCol == methodNames(m) & ...
                noiseCol == noiseTypes(n) & ...
                targetCol == snrLevels(s);

            k = k + 1;

            conditionMethods(k) = methodNames(m);
            conditionNoise(k) = noiseTypes(n);
            conditionTarget(k) = snrLevels(s);

            conditionCount(k) = sum(selected);

            if conditionCount(k) ~= 8
                error("Unexpected condition sample count.");
            end

            conditionSNR(k) = ...
                mean(snrGainCol(selected));

            conditionSTOI(k) = ...
                mean(outputStoiCol(selected));

        end
    end
end

conditionTable = table( ...
    conditionMethods, conditionNoise, ...
    conditionTarget, conditionCount, ...
    conditionSNR, conditionSTOI, ...
    'VariableNames', { ...
    'method', 'noise_type', 'target_snr_db', ...
    'sample_count', ...
    'mean_snr_improvement_db', ...
    'mean_output_stoi'});

writetable(conditionTable, fullfile( ...
    metricsRoot, "test_condition_summary.csv"));

%% =========================================================
% Paired differences against Basic baseline
%% =========================================================

pairedNames = methodNames(2:end);

pairedSNR = zeros(numMethods-1,1);
pairedSTOI = zeros(numMethods-1,1);

snrWinCount = zeros(numMethods-1,1);
stoiWinCount = zeros(numMethods-1,1);

baseRows = (0:numFiles-1)*numMethods + 1;

for m = 2:numMethods

    methodRows = baseRows + m - 1;

    deltaSNR = ...
        snrGainCol(methodRows) - snrGainCol(baseRows);

    deltaSTOI = ...
        outputStoiCol(methodRows) - outputStoiCol(baseRows);

    pairedSNR(m-1) = mean(deltaSNR);
    pairedSTOI(m-1) = mean(deltaSTOI);

    snrWinCount(m-1) = sum(deltaSNR > 0);
    stoiWinCount(m-1) = sum(deltaSTOI > 0);

end

pairedTable = table( ...
    pairedNames, pairedSNR, pairedSTOI, ...
    snrWinCount, stoiWinCount, ...
    'VariableNames', { ...
    'method', ...
    'mean_snr_difference_vs_basic_db', ...
    'mean_stoi_difference_vs_basic', ...
    'snr_better_count_out_of_48', ...
    'stoi_better_count_out_of_48'});

writetable(pairedTable, fullfile( ...
    metricsRoot, "test_paired_summary.csv"));

%% =========================================================
% Display final test results
%% =========================================================

fprintf("\n===== FINAL TEST SUMMARY =====\n");
fprintf("Test mixtures: %d\n", numFiles);
fprintf("Total evaluations: %d\n", rowIndex);
fprintf("Elapsed time: %.2f seconds\n", elapsedTime);

disp(overallTable);

fprintf("\n===== PAIRED COMPARISON VS BASIC =====\n");

disp(pairedTable);

fprintf("\n===== RESULTS BY NOISE AND SNR =====\n");

disp(conditionTable);

%% =========================================================
% Plot overall method comparison
%% =========================================================

figure('Position', [100, 150, 1150, 470]);

tiledlayout(1,2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

nexttile;

bar(meanSNR);

xticks(1:numMethods);
xticklabels(methodNames);
xtickangle(20);

ylabel("Mean SNR Improvement (dB)");
title("Reference-Based SNR Improvement");
grid on;

nexttile;

bar(meanSTOI);

xticks(1:numMethods);
xticklabels(methodNames);
xtickangle(20);

ylabel("Mean Output STOI");
title("Speech Intelligibility");
grid on;

sgtitle("Held-Out Test Set - Fixed Configurations");

exportgraphics(gcf, fullfile( ...
    figureRoot, "final_test_comparison.png"), ...
    'Resolution', 200);

%% =========================================================
% Plot paired differences against Basic
%% =========================================================

figure('Position', [160, 150, 1050, 430]);

tiledlayout(1,2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

nexttile;

bar(pairedSNR);

xticks(1:numMethods-1);
xticklabels(pairedNames);
xtickangle(20);

ylabel("Mean SNR Difference (dB)");
title("SNR Difference vs Basic");
yline(0, '--');
grid on;

nexttile;

bar(pairedSTOI);

xticks(1:numMethods-1);
xticklabels(pairedNames);
xtickangle(20);

ylabel("Mean STOI Difference");
title("STOI Difference vs Basic");
yline(0, '--');
grid on;

sgtitle("Held-Out Test Set - Paired Comparisons");

exportgraphics(gcf, fullfile( ...
    figureRoot, "final_test_paired_differences.png"), ...
    'Resolution', 200);

%% Final confirmation

fprintf("\n===== OUTPUT FILES =====\n");
fprintf("test_detailed_metrics.csv\n");
fprintf("test_overall_summary.csv\n");
fprintf("test_condition_summary.csv\n");
fprintf("test_paired_summary.csv\n");
fprintf("final_test_comparison.png\n");
fprintf("final_test_paired_differences.png\n");

fprintf("\nDone.\n");
