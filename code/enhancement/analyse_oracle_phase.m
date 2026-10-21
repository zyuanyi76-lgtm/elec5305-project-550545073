
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Oracle Clean-Phase Diagnostic
% Held-out test set
% Compare noisy phase against oracle clean phase
%% =========================================================

%% Project paths

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

addpath(fullfile(projectRoot, "code", "enhancement"));

testRoot = fullfile(projectRoot, ...
    "data", "mixtures", "test");

figureRoot = fullfile(projectRoot, ...
    "results", "figures");

metricsRoot = fullfile(projectRoot, ...
    "results", "metrics");

if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

if ~exist(metricsRoot, "dir")
    mkdir(metricsRoot);
end

%% Fixed STFT settings

prefixDuration = 0.5;
winLength = 512;
hopSize = 256;
nfft = 512;

%% Frozen configurations

methodNames = [
    "Basic"
    "SNR_focused"
    "STOI_focused"
    "Aggressive"
];

alphaSet = [1.0, 1.5, 1.0, 3.0];
betaSet = [0.00, 0.05, 0.05, 0.03];

numMethods = numel(methodNames);

%% Load held-out test files

files = dir(fullfile(testRoot, "*.mat"));
numFiles = numel(files);

if numFiles ~= 48
    error("Expected 48 test mixtures.");
end

totalRuns = numFiles * numMethods;

%% Preallocate results

fileCol = strings(totalRuns,1);
methodCol = strings(totalRuns,1);
noiseCol = strings(totalRuns,1);

targetCol = zeros(totalRuns,1);

noisyPhaseSNR = zeros(totalRuns,1);
oraclePhaseSNR = zeros(totalRuns,1);

noisyPhaseSTOI = zeros(totalRuns,1);
oraclePhaseSTOI = zeros(totalRuns,1);

snrDifference = zeros(totalRuns,1);
stoiDifference = zeros(totalRuns,1);

rowIndex = 0;

fprintf("===== ORACLE PHASE ANALYSIS =====\n");
fprintf("Test mixtures: %d\n", numFiles);
fprintf("Methods: %d\n", numMethods);
fprintf("Total comparisons: %d\n\n", totalRuns);

tic;

%% =========================================================
% Analyse all test mixtures
%% =========================================================

for f = 1:numFiles

    data = load(fullfile( ...
        files(f).folder, files(f).name));

    if string(data.splitName) ~= "test"
        error("Non-test mixture detected.");
    end

    fs = data.fs;

    if fs ~= 16000
        error("Unexpected sampling rate.");
    end

    clean = double(data.cleanReference(:));
    fullNoisy = double(data.fullNoisy(:));

    prefixSamples = round(prefixDuration * fs);

    %% Construct clean reference with noise-only prefix

    fullClean = [
        zeros(prefixSamples,1);
        clean
    ];

    if length(fullClean) ~= length(fullNoisy)
        error("Reference length mismatch.");
    end

    %% Obtain the oracle clean phase

    [cleanSTFT, ~] = stft_analysis_custom( ...
        fullClean, fs, winLength, hopSize, nfft);

    cleanPhase = angle(cleanSTFT);

    %% Compare methods

    for m = 1:numMethods

        alpha = alphaSet(m);
        beta = betaSet(m);

        %% Standard spectral subtraction

        result = modified_spectral_subtraction( ...
            fullNoisy, fs, prefixDuration, ...
            winLength, hopSize, nfft, ...
            alpha, beta);

        enhancedNoisyPhase = double( ...
            result.enhancedFull(prefixSamples+1:end));

        enhancedNoisyPhase = enhancedNoisyPhase(:);

        %% Replace noisy phase with clean phase
        % Keep the estimated magnitude unchanged

        estimatedMagnitude = abs(result.outputSTFT);

        oracleSpectrum = estimatedMagnitude .* ...
            exp(1i * cleanPhase);

        oracleFull = stft_synthesis_custom( ...
            oracleSpectrum, result.stftInfo);

        enhancedOraclePhase = double( ...
            oracleFull(prefixSamples+1:end));

        enhancedOraclePhase = enhancedOraclePhase(:);

        if length(enhancedOraclePhase) ~= length(clean)
            error("Oracle reconstruction length mismatch.");
        end

        %% Reference-based SNR

        errorNoisy = enhancedNoisyPhase - clean;
        errorOracle = enhancedOraclePhase - clean;

        snrNoisy = 10*log10( ...
            sum(clean.^2) / ...
            (sum(errorNoisy.^2) + eps));

        snrOracle = 10*log10( ...
            sum(clean.^2) / ...
            (sum(errorOracle.^2) + eps));

        %% STOI

        stoiNoisy = stoi( ...
            enhancedNoisyPhase, clean, fs);

        stoiOracle = stoi( ...
            enhancedOraclePhase, clean, fs);

        %% Store results

        rowIndex = rowIndex + 1;

        fileCol(rowIndex) = string(files(f).name);
        methodCol(rowIndex) = methodNames(m);
        noiseCol(rowIndex) = string(data.noiseType);

        targetCol(rowIndex) = data.targetSNR;

        noisyPhaseSNR(rowIndex) = snrNoisy;
        oraclePhaseSNR(rowIndex) = snrOracle;

        noisyPhaseSTOI(rowIndex) = stoiNoisy;
        oraclePhaseSTOI(rowIndex) = stoiOracle;

        snrDifference(rowIndex) = snrOracle - snrNoisy;
        stoiDifference(rowIndex) = stoiOracle - stoiNoisy;

    end

    fprintf("Processed %2d/%2d: %s\n", ...
        f, numFiles, files(f).name);

end

elapsedTime = toc;

%% =========================================================
% Save detailed metrics
%% =========================================================

detailedTable = table( ...
    fileCol, methodCol, noiseCol, targetCol, ...
    noisyPhaseSNR, oraclePhaseSNR, ...
    noisyPhaseSTOI, oraclePhaseSTOI, ...
    snrDifference, stoiDifference, ...
    'VariableNames', { ...
    'filename', 'method', 'noise_type', 'target_snr_db', ...
    'noisy_phase_snr_db', 'oracle_phase_snr_db', ...
    'noisy_phase_stoi', 'oracle_phase_stoi', ...
    'snr_difference_db', 'stoi_difference'});

writetable(detailedTable, ...
    fullfile(metricsRoot, ...
    "oracle_phase_detailed.csv"));

%% =========================================================
% Aggregate by method
%% =========================================================

meanNoisySNR = zeros(numMethods,1);
meanOracleSNR = zeros(numMethods,1);

meanNoisySTOI = zeros(numMethods,1);
meanOracleSTOI = zeros(numMethods,1);

meanSNRDifference = zeros(numMethods,1);
meanSTOIDifference = zeros(numMethods,1);

snrWinCount = zeros(numMethods,1);
stoiWinCount = zeros(numMethods,1);

for m = 1:numMethods

    selected = methodCol == methodNames(m);

    meanNoisySNR(m) = mean(noisyPhaseSNR(selected));
    meanOracleSNR(m) = mean(oraclePhaseSNR(selected));

    meanNoisySTOI(m) = mean(noisyPhaseSTOI(selected));
    meanOracleSTOI(m) = mean(oraclePhaseSTOI(selected));

    meanSNRDifference(m) = mean(snrDifference(selected));
    meanSTOIDifference(m) = mean(stoiDifference(selected));

    snrWinCount(m) = sum(snrDifference(selected) > 0);
    stoiWinCount(m) = sum(stoiDifference(selected) > 0);

end

summaryTable = table( ...
    methodNames, ...
    meanNoisySNR, meanOracleSNR, ...
    meanSNRDifference, ...
    meanNoisySTOI, meanOracleSTOI, ...
    meanSTOIDifference, ...
    snrWinCount, stoiWinCount, ...
    'VariableNames', { ...
    'method', ...
    'mean_noisy_phase_snr_db', ...
    'mean_oracle_phase_snr_db', ...
    'mean_snr_difference_db', ...
    'mean_noisy_phase_stoi', ...
    'mean_oracle_phase_stoi', ...
    'mean_stoi_difference', ...
    'snr_better_count', ...
    'stoi_better_count'});

writetable(summaryTable, ...
    fullfile(metricsRoot, ...
    "oracle_phase_summary.csv"));

%% =========================================================
% Display results
%% =========================================================

fprintf("\n===== ORACLE PHASE SUMMARY =====\n");

fprintf("Total comparisons: %d\n", rowIndex);
fprintf("Elapsed time: %.2f seconds\n", elapsedTime);

disp(summaryTable);

%% =========================================================
% Plot SNR and STOI differences
%% =========================================================

figure('Position', [100, 150, 1150, 470]);

tiledlayout(1,2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

nexttile;

bar(meanSNRDifference);

xticks(1:numMethods);
xticklabels(methodNames);
xtickangle(20);

ylabel("Oracle Minus Noisy-Phase SNR (dB)");
title("Reference-Based SNR Difference");

yline(0, '--');
grid on;

nexttile;

bar(meanSTOIDifference);

xticks(1:numMethods);
xticklabels(methodNames);
xtickangle(20);

ylabel("Oracle Minus Noisy-Phase STOI");
title("Intelligibility Difference");

yline(0, '--');
grid on;

sgtitle("Held-Out Test - Oracle Clean-Phase Diagnostic");

exportgraphics(gcf, ...
    fullfile(figureRoot, ...
    "oracle_phase_comparison.png"), ...
    'Resolution', 200);

fprintf("\n===== OUTPUT FILES =====\n");

fprintf("oracle_phase_detailed.csv\n");
fprintf("oracle_phase_summary.csv\n");
fprintf("oracle_phase_comparison.png\n");

fprintf("\nDone.\n");
