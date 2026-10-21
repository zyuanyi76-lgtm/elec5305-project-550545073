
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Final Pretrained Model Validation
% Development set only
% Check alignment and amplitude characteristics
%% =========================================================

%% Project paths

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

modelRoot = fullfile(projectRoot, ...
    "external", "enhanceSpeechModel");

addpath(genpath(modelRoot));

devRoot = fullfile(projectRoot, ...
    "data", "mixtures", "dev");

metricsRoot = fullfile(projectRoot, ...
    "results", "metrics");

if ~exist(metricsRoot, "dir")
    mkdir(metricsRoot);
end

%% Load development files

files = dir(fullfile(devRoot, "*.mat"));
numFiles = numel(files);

if numFiles ~= 24
    error("Expected 24 development mixtures.");
end

%% Preallocate results

fileNames = strings(numFiles,1);

estimatedLag = zeros(numFiles,1);
peakCorrelation = zeros(numFiles,1);
rmsRatio = zeros(numFiles,1);

rawSNR = zeros(numFiles,1);
oracleScaledSNR = zeros(numFiles,1);
oracleGain = zeros(numFiles,1);

rawSTOI = zeros(numFiles,1);

%% Alignment search settings

maxLagMs = 100;

fprintf("===== PRETRAINED MODEL VALIDATION =====\n");
fprintf("Development mixtures: %d\n", numFiles);

tic;

%% =========================================================
% Validate every development mixture
%% =========================================================

for i = 1:numFiles

    data = load(fullfile( ...
        files(i).folder, files(i).name));

    if string(data.splitName) ~= "dev"
        error("Non-development data detected.");
    end

    fs = data.fs;

    if fs ~= 16000
        error("Unexpected sampling rate.");
    end

    clean = double(data.cleanReference(:));
    noisy = double(data.noisySpeech(:));

    %% Run pretrained model

    enhanced = double(enhanceSpeech(noisy, fs));
    enhanced = enhanced(:);

    if numel(enhanced) ~= numel(clean)
        error("Output length mismatch.");
    end

    if any(~isfinite(enhanced))
        error("Invalid model output.");
    end

    %% Estimate input-output lag

    maxLag = round(maxLagMs * fs / 1000);

    [c, lags] = xcorr( ...
        enhanced, noisy, maxLag, 'coeff');

    [peakCorrelation(i), idx] = max(c);

    estimatedLag(i) = lags(idx);

    %% RMS ratio

    cleanRMS = sqrt(mean(clean.^2));
    enhancedRMS = sqrt(mean(enhanced.^2));

    rmsRatio(i) = enhancedRMS / max(cleanRMS, eps);

    %% Original reference-based SNR

    rawError = enhanced - clean;

    rawSNR(i) = 10*log10( ...
        sum(clean.^2) / ...
        max(sum(rawError.^2), eps));

    %% Original STOI

    rawSTOI(i) = stoi(enhanced, clean, fs);

    %% Oracle amplitude diagnostic
    % Uses clean reference: diagnostic only

    oracleGain(i) = ...
        sum(enhanced .* clean) / ...
        max(sum(enhanced.^2), eps);

    scaled = enhanced * oracleGain(i);

    scaledError = scaled - clean;

    oracleScaledSNR(i) = 10*log10( ...
        sum(clean.^2) / ...
        max(sum(scaledError.^2), eps));

    %% Store filename

    fileNames(i) = string(files(i).name);

    fprintf( ...
        "%2d/%2d | Lag %+5d | RMS ratio %.3f | SNR %.2f dB\n", ...
        i, numFiles, estimatedLag(i), ...
        rmsRatio(i), rawSNR(i));

end

elapsedTime = toc;

%% =========================================================
% Save diagnostics
%% =========================================================

resultsTable = table( ...
    fileNames, estimatedLag, peakCorrelation, ...
    rmsRatio, rawSNR, oracleScaledSNR, ...
    oracleGain, rawSTOI, ...
    'VariableNames', { ...
    'filename', ...
    'estimated_lag_samples', ...
    'peak_input_output_correlation', ...
    'enhanced_clean_rms_ratio', ...
    'raw_output_snr_db', ...
    'oracle_scaled_snr_db', ...
    'oracle_gain', ...
    'raw_output_stoi'});

writetable(resultsTable, ...
    fullfile(metricsRoot, ...
    "pretrained_development_validation.csv"));

%% =========================================================
% Final summary
%% =========================================================

fprintf("\n===== FINAL VALIDATION SUMMARY =====\n");

fprintf("Files checked: %d\n", numFiles);

fprintf("Zero-lag files: %d/%d\n", ...
    sum(estimatedLag == 0), numFiles);

fprintf("Median absolute lag: %.1f samples\n", ...
    median(abs(estimatedLag)));

fprintf("Maximum absolute lag: %d samples\n", ...
    max(abs(estimatedLag)));

fprintf("Mean peak correlation: %.4f\n", ...
    mean(peakCorrelation));

fprintf("Mean enhanced/clean RMS ratio: %.4f\n", ...
    mean(rmsRatio));

fprintf("Mean raw output SNR: %.4f dB\n", ...
    mean(rawSNR));

fprintf("Mean oracle-scaled SNR: %.4f dB\n", ...
    mean(oracleScaledSNR));

fprintf("Mean diagnostic SNR difference: %.4f dB\n", ...
    mean(oracleScaledSNR - rawSNR));

fprintf("Mean output STOI: %.4f\n", ...
    mean(rawSTOI));

fprintf("Elapsed time: %.2f seconds\n", elapsedTime);

if all(estimatedLag == 0)
    fprintf("PASS: No fixed lag detected in development files.\n");
else
    fprintf("CHECK: Nonzero lag detected in some files.\n");
end

fprintf("\nValidation CSV saved.\n");
fprintf("Done.\n");
