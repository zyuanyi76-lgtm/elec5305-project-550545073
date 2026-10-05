clear;
clc;
close all;

%% =========================================================
%  ELEC5305
%  Validate STFT -> ISTFT reconstruction
%% =========================================================

projectRoot = ...
    "D:\课件\5305\elec5305-project-550545073";

enhancementRoot = fullfile( ...
    projectRoot, ...
    "code", ...
    "enhancement");

addpath(enhancementRoot);

%% Load one development mixture

devRoot = fullfile( ...
    projectRoot, ...
    "data", ...
    "mixtures", ...
    "dev");

files = dir(fullfile(devRoot, "*.mat"));

if isempty(files)
    error("No development MAT files found.");
end

testFile = fullfile( ...
    files(1).folder, ...
    files(1).name);

data = load(testFile);

x = data.fullNoisy;
fs = data.fs;

fprintf("Test file:\n%s\n\n", files(1).name);

%% Fixed STFT parameters

winLength = 512;
hopSize = 256;
nfft = 512;

fprintf("===== STFT SETTINGS =====\n");
fprintf("Sample rate: %d Hz\n", fs);
fprintf("Window: Hann\n");
fprintf("Window length: %d samples (%.1f ms)\n", ...
    winLength, ...
    1000*winLength/fs);

fprintf("Hop size: %d samples\n", hopSize);
fprintf("Overlap: %.0f %%\n", ...
    100*(1-hopSize/winLength));

fprintf("FFT size: %d\n\n", nfft);

%% STFT

[X, info] = stft_analysis_custom( ...
    x, ...
    fs, ...
    winLength, ...
    hopSize, ...
    nfft);

%% ISTFT without any modification

y = stft_synthesis_custom(X, info);

%% Reconstruction error

errorSignal = x - y;

rmse = sqrt(mean(errorSignal.^2));

maxAbsError = max(abs(errorSignal));

reconstructionSNR = ...
    10*log10( ...
    sum(x.^2) / ...
    (sum(errorSignal.^2) + eps));

fprintf("===== RECONSTRUCTION CHECK =====\n");

fprintf("Original length: %d samples\n", ...
    length(x));

fprintf("Reconstructed length: %d samples\n", ...
    length(y));

fprintf("RMSE: %.12e\n", rmse);

fprintf("Maximum absolute error: %.12e\n", ...
    maxAbsError);

fprintf("Reconstruction SNR: %.2f dB\n", ...
    reconstructionSNR);

%% Pass / fail

if length(x) == length(y)
    fprintf("PASS: Signal length preserved.\n");
else
    warning("Signal length mismatch.");
end

if maxAbsError < 1e-10
    fprintf("PASS: Near-perfect reconstruction.\n");
else
    warning("Reconstruction error is larger than expected.");
end

%% =========================================================
% Plot
%% =========================================================

t = (0:length(x)-1)/fs;

figure;

subplot(3,1,1);

plot(t, x);

xlabel("Time (s)");
ylabel("Amplitude");

title("Original Noisy Signal");

grid on;

subplot(3,1,2);

plot(t, y);

xlabel("Time (s)");
ylabel("Amplitude");

title("STFT-ISTFT Reconstruction");

grid on;

subplot(3,1,3);

plot(t, errorSignal);

xlabel("Time (s)");
ylabel("Error");

title("Reconstruction Error");

grid on;

%% Save figure

figureRoot = fullfile( ...
    projectRoot, ...
    "results", ...
    "figures");

if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

saveas(gcf, ...
    fullfile( ...
    figureRoot, ...
    "stft_istft_reconstruction_check.png"));

fprintf("\nFigure saved.\n");
fprintf("Done.\n");