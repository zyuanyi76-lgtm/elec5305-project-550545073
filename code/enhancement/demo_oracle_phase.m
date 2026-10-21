
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Oracle Phase Listening Demonstration
% Basic spectral subtraction
% One fixed held-out test example
%% =========================================================

%% Project paths

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

addpath(fullfile(projectRoot, "code", "enhancement"));

testRoot = fullfile(projectRoot, ...
    "data", "mixtures", "test");

audioRoot = fullfile(projectRoot, ...
    "results", "audio", "oracle_phase");

figureRoot = fullfile(projectRoot, ...
    "results", "figures");

if ~exist(audioRoot, "dir")
    mkdir(audioRoot);
end

if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

%% Select a fixed test example

fileName = "237-126133-0003__environmental__0dB.mat";

data = load(fullfile(testRoot, fileName));

if string(data.splitName) ~= "test"
    error("Expected held-out test data.");
end

fs = data.fs;
clean = double(data.cleanReference(:));
noise = double(data.noiseReference(:));
fullNoisy = double(data.fullNoisy(:));

noisy = clean + noise;

%% Fixed STFT parameters

prefixDuration = 0.5;
prefixSamples = round(prefixDuration * fs);

winLength = 512;
hopSize = 256;
nfft = 512;

%% Basic spectral subtraction

result = basic_spectral_subtraction( ...
    fullNoisy, fs, prefixDuration, ...
    winLength, hopSize, nfft);

basicSpeech = double( ...
    result.enhancedFull(prefixSamples+1:end));

%% Oracle clean phase

fullClean = [
    zeros(prefixSamples,1);
    clean
];

[cleanSTFT, ~] = stft_analysis_custom( ...
    fullClean, fs, winLength, hopSize, nfft);

oracleSpectrum = abs(result.outputSTFT) .* ...
    exp(1i * angle(cleanSTFT));

oracleFull = stft_synthesis_custom( ...
    oracleSpectrum, result.stftInfo);

oracleSpeech = double( ...
    oracleFull(prefixSamples+1:end));

%% Prepare comparison signals

signals = {
    clean
    noisy
    basicSpeech
    oracleSpeech
};

titles = [
    "Clean Speech"
    "Noisy Speech"
    "Basic - Noisy Phase"
    "Basic - Oracle Clean Phase"
];

%% Calculate metrics

fprintf("===== ORACLE PHASE DEMONSTRATION =====\n");

for k = 2:4

    x = signals{k};

    errorSignal = x - clean;

    snrValue = 10*log10( ...
        sum(clean.^2) / ...
        (sum(errorSignal.^2) + eps));

    stoiValue = stoi(x, clean, fs);

    fprintf("%s\n", titles(k));
    fprintf("SNR: %.3f dB\n", snrValue);
    fprintf("STOI: %.4f\n\n", stoiValue);

end

%% Plot spectrograms

window = hann(winLength, 'periodic');

spectra = cell(4,1);

for k = 1:4

    [S, F, T] = spectrogram( ...
        signals{k}, window, hopSize, nfft, fs);

    spectra{k} = 20*log10(abs(S) + 1e-12);

end

commonMax = max(spectra{2}(:));
commonMin = commonMax - 75;

figure('Position', [100, 80, 1100, 800]);

tiledlayout(4,1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

for k = 1:4

    nexttile;

    imagesc(T, F/1000, spectra{k});

    axis xy;
    ylim([0,8]);
    clim([commonMin, commonMax]);

    xlabel("Time (s)");
    ylabel("Frequency (kHz)");
    title(titles(k));

end

colormap(turbo);

sgtitle("Basic Spectral Subtraction - Phase Comparison");

cb = colorbar;
cb.Layout.Tile = 'east';
cb.Label.String = "Magnitude (dB)";

exportgraphics(gcf, ...
    fullfile(figureRoot, ...
    "oracle_phase_spectrogram_demo.png"), ...
    'Resolution', 200);

%% Save audio with a common gain

audioNames = [
    "01_clean.wav"
    "02_noisy.wav"
    "03_basic_noisy_phase.wav"
    "04_basic_oracle_phase.wav"
];

globalPeak = 0;

for k = 1:4
    globalPeak = max( ...
        globalPeak, max(abs(signals{k})));
end

commonGain = min(1, 0.99/max(globalPeak, eps));

for k = 1:4

    audiowrite( ...
        fullfile(audioRoot, audioNames(k)), ...
        signals{k} * commonGain, fs);

end

fprintf("===== OUTPUT =====\n");
fprintf("Four audio files saved.\n");
fprintf("Oracle spectrogram comparison saved.\n");
fprintf("Done.\n");
