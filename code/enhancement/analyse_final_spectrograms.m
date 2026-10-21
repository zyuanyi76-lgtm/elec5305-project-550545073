
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Spectrogram and Listening Comparison
% Fixed parameters on one held-out test example
%% =========================================================

%% Project paths

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

addpath(fullfile(projectRoot, "code", "enhancement"));

testRoot = fullfile(projectRoot, ...
    "data", "mixtures", "test");

figureRoot = fullfile(projectRoot, ...
    "results", "figures");

audioRoot = fullfile(projectRoot, ...
    "results", "audio", "final_comparison");

if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

if ~exist(audioRoot, "dir")
    mkdir(audioRoot);
end

%% Select a fixed test example

files = dir(fullfile( ...
    testRoot, "*__environmental__0dB.mat"));

if isempty(files)
    error("No matching test mixture found.");
end

data = load(fullfile(files(1).folder, files(1).name));

fs = data.fs;

if string(data.splitName) ~= "test" || fs ~= 16000
    error("Unexpected test data.");
end

clean = double(data.cleanReference(:));
noise = double(data.noiseReference(:));
fullNoisy = double(data.fullNoisy(:));

noisy = clean + noise;

fprintf("===== SELECTED TEST EXAMPLE =====\n");
fprintf("File: %s\n", files(1).name);

%% Fixed processing parameters

prefixDuration = 0.5;
prefixSamples = round(prefixDuration * fs);

winLength = 512;
hopSize = 256;
nfft = 512;

%% Frozen enhancement configurations

methodNames = [
    "Basic"
    "SNR-focused"
    "STOI-focused"
    "Aggressive"
];

alphaSet = [1.0, 1.5, 1.0, 3.0];
betaSet = [0.00, 0.05, 0.05, 0.03];

%% Store reference signals

signals = cell(6,1);

signals{1} = clean;
signals{2} = noisy;

titles = strings(6,1);

titles(1) = "Clean Speech";
titles(2) = "Noisy Speech - Environmental, 0 dB";

%% Run all frozen methods

fprintf("\n===== METHOD COMPARISON =====\n");

for k = 1:4

    result = modified_spectral_subtraction( ...
        fullNoisy, fs, prefixDuration, ...
        winLength, hopSize, nfft, ...
        alphaSet(k), betaSet(k));

    enhanced = double( ...
        result.enhancedFull(prefixSamples+1:end));

    enhanced = enhanced(:);

    if numel(enhanced) ~= numel(clean)
        error("Signal length mismatch.");
    end

    signals{k+2} = enhanced;

    outputError = enhanced - clean;

    outputSNR = 10*log10( ...
        sum(clean.^2) / ...
        (sum(outputError.^2) + eps));

    outputSTOI = stoi(enhanced, clean, fs);

    titles(k+2) = sprintf( ...
        "%s - SNR %.2f dB, STOI %.3f", ...
        methodNames(k), outputSNR, outputSTOI);

    fprintf("%-14s | SNR %.3f dB | STOI %.4f\n", ...
        methodNames(k), outputSNR, outputSTOI);

end

%% =========================================================
% Calculate spectrograms with identical settings
%% =========================================================

window = hann(winLength, 'periodic');
noverlap = winLength - hopSize;

spectrogramDb = cell(6,1);

for k = 1:6

    [S, F, T] = spectrogram( ...
        signals{k}, window, noverlap, nfft, fs);

    spectrogramDb{k} = ...
        20*log10(abs(S) + 1e-12);

end

%% Use one common color scale

maxDb = max(spectrogramDb{2}(:));

minDb = maxDb - 75;

%% =========================================================
% Plot six spectrograms
%% =========================================================

figure('Position', [80, 50, 1150, 1050]);

tiledlayout(6,1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

for k = 1:6

    nexttile;

    imagesc(T, F/1000, spectrogramDb{k});

    axis xy;

    ylim([0, 8]);

    clim([minDb, maxDb]);

    xlabel("Time (s)");
    ylabel("Frequency (kHz)");

    title(titles(k));

    cb = colorbar;
    cb.Label.String = "Magnitude (dB)";

end

colormap(turbo);

sgtitle("Held-Out Test - Spectrogram Comparison");

%% Save spectrogram

exportgraphics(gcf, ...
    fullfile(figureRoot, ...
    "final_spectrogram_comparison.png"), ...
    'Resolution', 200);

%% =========================================================
% Save listening examples
% Apply one common gain only if clipping is possible
%% =========================================================

audioNames = [
    "01_clean.wav"
    "02_noisy.wav"
    "03_basic.wav"
    "04_snr_focused.wav"
    "05_stoi_focused.wav"
    "06_aggressive.wav"
];

globalPeak = 0;

for k = 1:6
    globalPeak = max( ...
        globalPeak, max(abs(signals{k})));
end

commonGain = min(1, 0.99/max(globalPeak, eps));

fprintf("\nCommon listening gain: %.6f\n", commonGain);

for k = 1:6

    outputAudio = fullfile(audioRoot, audioNames(k));

    audiowrite(outputAudio, ...
        signals{k} * commonGain, fs);

end

fprintf("\n===== OUTPUT =====\n");
fprintf("Saved: final_spectrogram_comparison.png\n");
fprintf("Saved: Six listening WAV files\n");
fprintf("Done.\n");
