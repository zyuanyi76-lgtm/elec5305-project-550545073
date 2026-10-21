
clear;
clc;
close all;

%% Project paths

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

enhancementRoot = fullfile( ...
    projectRoot, "code", "enhancement");

addpath(enhancementRoot);

%% Load a development example

devRoot = fullfile( ...
    projectRoot, "data", "mixtures", "dev");

files = dir(fullfile( ...
    devRoot, "*__environmental__0dB.mat"));

if isempty(files)
    error("No matching development mixture found.");
end

data = load(fullfile(files(1).folder, files(1).name));

fullNoisy = data.fullNoisy;
cleanReference = data.cleanReference;
noiseReference = data.noiseReference;
fs = data.fs;

%% Fixed STFT settings

prefixDuration = 0.5;
winLength = 512;
hopSize = 256;
nfft = 512;

%% Initial experimental parameters

alpha = 2.0;
beta = 0.03;

% These are example parameters, not optimised values.

%% Basic method

basicResult = basic_spectral_subtraction( ...
    fullNoisy, fs, prefixDuration, ...
    winLength, hopSize, nfft);

%% Modified method

modifiedResult = modified_spectral_subtraction( ...
    fullNoisy, fs, prefixDuration, ...
    winLength, hopSize, nfft, alpha, beta);

%% Check equivalence with the basic method

referenceResult = modified_spectral_subtraction( ...
    fullNoisy, fs, prefixDuration, ...
    winLength, hopSize, nfft, 1.0, 0.0);

baselineDifference = max(abs( ...
    basicResult.enhancedFull - ...
    referenceResult.enhancedFull));

fprintf("===== BASELINE EQUIVALENCE CHECK =====\n");
fprintf("Maximum difference: %.12e\n", baselineDifference);

if baselineDifference < 1e-10
    fprintf("PASS: Alpha=1 and beta=0 reproduce the baseline.\n");
else
    warning("Baseline equivalence check failed.");
end

%% Extract speech-only regions

prefixSamples = round(prefixDuration * fs);

basicSpeech = basicResult.enhancedFull( ...
    prefixSamples+1:end);

modifiedSpeech = modifiedResult.enhancedFull( ...
    prefixSamples+1:end);

L = length(cleanReference);

assert(length(basicSpeech) == L);
assert(length(modifiedSpeech) == L);

cleanReference = cleanReference(:);
noiseReference = noiseReference(:);

noisySpeech = cleanReference + noiseReference;

%% Calculate SNR

inputSNR = calculateSNR( ...
    cleanReference, noisySpeech);

basicSNR = calculateSNR( ...
    cleanReference, basicSpeech);

modifiedSNR = calculateSNR( ...
    cleanReference, modifiedSpeech);

%% Display results

fprintf("\n===== MODIFIED SPECTRAL SUBTRACTION =====\n");

fprintf("Alpha: %.2f\n", alpha);
fprintf("Beta: %.3f\n", beta);

fprintf("Input SNR: %.3f dB\n", inputSNR);
fprintf("Basic output SNR: %.3f dB\n", basicSNR);
fprintf("Modified output SNR: %.3f dB\n", modifiedSNR);

fprintf("Basic SNR improvement: %.3f dB\n", ...
    basicSNR - inputSNR);

fprintf("Modified SNR improvement: %.3f dB\n", ...
    modifiedSNR - inputSNR);

fprintf("Modified minus Basic: %.3f dB\n", ...
    modifiedSNR - basicSNR);

fprintf("Modified gain range: %.3f to %.3f\n", ...
    min(modifiedResult.gain(:)), ...
    max(modifiedResult.gain(:)));

%% Plot comparison

t = (0:L-1)/fs;

figure;

subplot(4,1,1);
plot(t, cleanReference);
title("Clean Speech");
xlabel("Time (s)");
ylabel("Amplitude");
grid on;

subplot(4,1,2);
plot(t, noisySpeech);
title(sprintf("Noisy Speech - Input SNR %.2f dB", inputSNR));
xlabel("Time (s)");
ylabel("Amplitude");
grid on;

subplot(4,1,3);
plot(t, basicSpeech);
title(sprintf("Basic Spectral Subtraction - %.2f dB", basicSNR));
xlabel("Time (s)");
ylabel("Amplitude");
grid on;

subplot(4,1,4);
plot(t, modifiedSpeech);
title(sprintf( ...
    "Modified Spectral Subtraction - Alpha %.1f, Beta %.2f, SNR %.2f dB", ...
    alpha, beta, modifiedSNR));
xlabel("Time (s)");
ylabel("Amplitude");
grid on;

%% Save figure

figureRoot = fullfile(projectRoot, ...
    "results", "figures");

if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

saveas(gcf, fullfile(figureRoot, ...
    "basic_vs_modified_waveforms.png"));

%% Save audio examples

audioRoot = fullfile(projectRoot, ...
    "results", "audio");

if ~exist(audioRoot, "dir")
    mkdir(audioRoot);
end

saveListeningAudio(basicSpeech, ...
    fullfile(audioRoot, "comparison_basic.wav"), fs);

saveListeningAudio(modifiedSpeech, ...
    fullfile(audioRoot, "comparison_modified.wav"), fs);

fprintf("\nComparison figure and audio saved.\n");
fprintf("Done.\n");

%% Local functions

function snrValue = calculateSNR(clean, signal)

    errorSignal = signal - clean;

    snrValue = 10*log10( ...
        sum(clean.^2) / ...
        (sum(errorSignal.^2) + eps));

end

function saveListeningAudio(x, filename, fs)

    peakValue = max(abs(x));

    if peakValue > 0.99
        x = x * (0.99 / peakValue);
    end

    audiowrite(filename, x, fs);

end
