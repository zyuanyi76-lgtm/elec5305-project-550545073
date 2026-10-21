
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Speech and Noise Decomposition
% Development set only
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

%% Fixed STFT parameters

fsExpected = 16000;
prefixDuration = 0.5;

winLength = 512;
hopSize = 256;
nfft = 512;

%% Representative parameter configurations

alphaValues = [1, 1.5, 2, 2.5, 3, 1, 1.5, 1];
betaValues = [0.03, 0.03, 0.03, 0.03, 0.03, ...
              0, 0.05, 0.05];

configNames = strings(numel(alphaValues), 1);

for k = 1:numel(alphaValues)
    configNames(k) = sprintf( ...
        "Alpha_%.1f_Beta_%.2f", ...
        alphaValues(k), betaValues(k));
end

numConfigs = numel(alphaValues);

%% Load development mixtures

files = dir(fullfile(devRoot, "*.mat"));
numFiles = numel(files);

if numFiles ~= 24
    error("Expected 24 development mixtures.");
end

totalRuns = numFiles * numConfigs;

%% Preallocate result arrays

fileCol = strings(totalRuns, 1);
noiseCol = strings(totalRuns, 1);
configCol = strings(totalRuns, 1);

alphaCol = zeros(totalRuns, 1);
betaCol = zeros(totalRuns, 1);

noiseAttenuationDb = zeros(totalRuns, 1);
speechAttenuationDb = zeros(totalRuns, 1);
speechDistortionPct = zeros(totalRuns, 1);
referenceOutputSnrDb = zeros(totalRuns, 1);

maxDecompositionError = 0;
rowIndex = 0;

fprintf("===== SPEECH-NOISE DECOMPOSITION =====\n");
fprintf("Development mixtures: %d\n", numFiles);
fprintf("Configurations: %d\n", numConfigs);
fprintf("Total evaluations: %d\n\n", totalRuns);

tic;

%% =========================================================
% Process all development mixtures
%% =========================================================

for f = 1:numFiles

    data = load(fullfile( ...
        files(f).folder, files(f).name));

    if string(data.splitName) ~= "dev"
        error("Non-development file detected.");
    end

    fs = data.fs;

    if fs ~= fsExpected
        error("Unexpected sample rate.");
    end

    clean = double(data.cleanReference(:));
    noise = double(data.noiseReference(:));
    noisePrefix = double(data.noisePrefix(:));
    fullNoisy = double(data.fullNoisy(:));

    prefixSamples = round(prefixDuration * fs);

    if length(noisePrefix) ~= prefixSamples
        error("Noise prefix length mismatch.");
    end

    %% Reconstruct exact clean and noise components

    fullClean = [
        zeros(prefixSamples, 1);
        clean
    ];

    fullNoise = [
        noisePrefix;
        noise
    ];

    if length(fullClean) ~= length(fullNoisy)
        error("Full signal length mismatch.");
    end

    mixtureError = max(abs( ...
        fullNoisy - (fullClean + fullNoise)));

    if mixtureError > 1e-10
        error("Mixture decomposition check failed.");
    end

    %% STFT of known components

    [cleanSTFT, ~] = stft_analysis_custom( ...
        fullClean, fs, winLength, hopSize, nfft);

    [noiseSTFT, ~] = stft_analysis_custom( ...
        fullNoise, fs, winLength, hopSize, nfft);

    %% Apply the same mixture-derived gain to both components

    for k = 1:numConfigs

        alpha = alphaValues(k);
        beta = betaValues(k);

        result = modified_spectral_subtraction( ...
            fullNoisy, fs, prefixDuration, ...
            winLength, hopSize, nfft, alpha, beta);

        gain = result.gain;
        stftInfo = result.stftInfo;

        %% Filter desired speech with the original gain

        processedCleanFull = stft_synthesis_custom( ...
            cleanSTFT .* gain, stftInfo);

        %% Filter noise with exactly the same gain

        processedNoiseFull = stft_synthesis_custom( ...
            noiseSTFT .* gain, stftInfo);

        %% Verify decomposition consistency

        reconstructedFull = ...
            processedCleanFull + processedNoiseFull;

        decompositionError = max(abs( ...
            result.enhancedFull - reconstructedFull));

        maxDecompositionError = max( ...
            maxDecompositionError, decompositionError);

        if decompositionError > 1e-10
            error("Output decomposition check failed.");
        end

        %% Remove noise-only prefix

        idx = prefixSamples + 1:length(fullNoisy);

        processedClean = processedCleanFull(idx);
        processedNoise = processedNoiseFull(idx);
        enhancedSpeech = result.enhancedFull(idx);

        %% Residual noise attenuation

        originalNoiseEnergy = sum(noise.^2);
        residualNoiseEnergy = sum(processedNoise.^2);

        noiseReduction = 10 * log10( ...
            originalNoiseEnergy / ...
            max(residualNoiseEnergy, eps));

        %% Desired speech energy attenuation

        originalSpeechEnergy = sum(clean.^2);
        processedSpeechEnergy = sum(processedClean.^2);

        speechAttenuation = 10 * log10( ...
            originalSpeechEnergy / ...
            max(processedSpeechEnergy, eps));

        %% Speech distortion energy relative to clean speech

        speechDistortionEnergy = sum( ...
            (processedClean - clean).^2);

        distortionPercent = 100 * ...
            speechDistortionEnergy / ...
            max(originalSpeechEnergy, eps);

        %% Reference-based output SNR

        totalError = enhancedSpeech - clean;

        outputSNR = 10 * log10( ...
            originalSpeechEnergy / ...
            max(sum(totalError.^2), eps));

        %% Store measurements

        rowIndex = rowIndex + 1;

        fileCol(rowIndex) = string(files(f).name);
        noiseCol(rowIndex) = string(data.noiseType);
        configCol(rowIndex) = configNames(k);

        alphaCol(rowIndex) = alpha;
        betaCol(rowIndex) = beta;

        noiseAttenuationDb(rowIndex) = noiseReduction;
        speechAttenuationDb(rowIndex) = speechAttenuation;
        speechDistortionPct(rowIndex) = distortionPercent;
        referenceOutputSnrDb(rowIndex) = outputSNR;

    end

    fprintf("Processed %d/%d: %s\n", ...
        f, numFiles, files(f).name);

end

elapsedTime = toc;

%% =========================================================
% Save detailed results
%% =========================================================

detailedTable = table( ...
    fileCol, noiseCol, configCol, ...
    alphaCol, betaCol, ...
    noiseAttenuationDb, ...
    speechAttenuationDb, ...
    speechDistortionPct, ...
    referenceOutputSnrDb, ...
    'VariableNames', { ...
    'filename', 'noise_type', 'configuration', ...
    'alpha', 'beta', ...
    'noise_attenuation_db', ...
    'speech_attenuation_db', ...
    'speech_distortion_percent', ...
    'reference_output_snr_db'});

writetable(detailedTable, ...
    fullfile(metricsRoot, ...
    "speech_noise_decomposition_detailed.csv"));

%% =========================================================
% Aggregate results by parameter configuration
%% =========================================================

meanNoise = zeros(numConfigs, 1);
meanSpeech = zeros(numConfigs, 1);
meanDistortion = zeros(numConfigs, 1);
meanOutputSNR = zeros(numConfigs, 1);

for k = 1:numConfigs

    selected = configCol == configNames(k);

    meanNoise(k) = mean( ...
        noiseAttenuationDb(selected));

    meanSpeech(k) = mean( ...
        speechAttenuationDb(selected));

    meanDistortion(k) = mean( ...
        speechDistortionPct(selected));

    meanOutputSNR(k) = mean( ...
        referenceOutputSnrDb(selected));

end

summaryTable = table( ...
    configNames, alphaValues(:), betaValues(:), ...
    meanNoise, meanSpeech, ...
    meanDistortion, meanOutputSNR, ...
    'VariableNames', { ...
    'configuration', 'alpha', 'beta', ...
    'mean_noise_attenuation_db', ...
    'mean_speech_attenuation_db', ...
    'mean_speech_distortion_percent', ...
    'mean_reference_output_snr_db'});

writetable(summaryTable, ...
    fullfile(metricsRoot, ...
    "speech_noise_decomposition_summary.csv"));

%% =========================================================
% Display results
%% =========================================================

fprintf("\n===== DECOMPOSITION CHECK =====\n");
fprintf("Maximum decomposition error: %.12e\n", ...
    maxDecompositionError);

fprintf("PASS: Output decomposition verified.\n");

fprintf("\n===== SUMMARY =====\n");
fprintf("Total evaluations: %d\n", rowIndex);
fprintf("Elapsed time: %.2f seconds\n", elapsedTime);

disp(summaryTable);

fprintf("\n===== REPRESENTATIVE CONFIGURATIONS =====\n");
disp(summaryTable(6:8, :));

%% =========================================================
% Plot noise suppression and speech distortion
% Fixed beta = 0.03
%% =========================================================

sweepIdx = 1:5;
sweepAlpha = alphaValues(sweepIdx);

figure('Position', [100, 150, 1150, 450]);

tiledlayout(1,2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

nexttile;

plot(sweepAlpha, meanNoise(sweepIdx), ...
    '-o', 'LineWidth', 1.8, 'MarkerSize', 7);

xlabel("Alpha (Over-subtraction)");
ylabel("Residual Noise Attenuation (dB)");
title("Noise Suppression");
grid on;

nexttile;

plot(sweepAlpha, meanDistortion(sweepIdx), ...
    '-s', 'LineWidth', 1.8, 'MarkerSize', 7);

xlabel("Alpha (Over-subtraction)");
ylabel("Speech Distortion Energy (%)");
title("Desired Speech Distortion");
grid on;

sgtitle("Development Set - Fixed Beta = 0.03");

exportgraphics(gcf, ...
    fullfile(figureRoot, ...
    "speech_noise_tradeoff.png"), ...
    'Resolution', 200);

fprintf("\n===== OUTPUT FILES =====\n");
fprintf("speech_noise_decomposition_detailed.csv\n");
fprintf("speech_noise_decomposition_summary.csv\n");
fprintf("speech_noise_tradeoff.png\n");

fprintf("\nDone.\n");
