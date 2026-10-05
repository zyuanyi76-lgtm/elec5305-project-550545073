clear;
clc;
close all;

%% =========================================================
% ELEC5305
% Demo - Basic Spectral Subtraction
%% =========================================================

projectRoot = ...
    "D:\课件\5305\elec5305-project-550545073";

enhancementRoot = fullfile( ...
    projectRoot, ...
    "code", ...
    "enhancement");

addpath(enhancementRoot);

%% =========================================================
% Load one development example
%% =========================================================

devRoot = fullfile( ...
    projectRoot, ...
    "data", ...
    "mixtures", ...
    "dev");

% Start with a difficult example:
% environmental noise at 0 dB

files = dir(fullfile( ...
    devRoot, ...
    "*__environmental__0dB.mat"));

if isempty(files)
    error("No environmental 0 dB development file found.");
end

testFile = fullfile( ...
    files(1).folder, ...
    files(1).name);

data = load(testFile);

fullNoisy = data.fullNoisy;
cleanReference = data.cleanReference;
noiseReference = data.noiseReference;

fs = data.fs;

fprintf("Test file:\n%s\n\n", ...
    files(1).name);

%% Fixed parameters

prefixDuration = 0.5;

winLength = 512;
hopSize = 256;
nfft = 512;

%% =========================================================
% Run basic spectral subtraction
%% =========================================================

result = basic_spectral_subtraction( ...
    fullNoisy, ...
    fs, ...
    prefixDuration, ...
    winLength, ...
    hopSize, ...
    nfft);

enhancedFull = result.enhancedFull;

%% =========================================================
% Remove noise-only prefix for evaluation
%% =========================================================

prefixSamples = round(prefixDuration * fs);

enhancedSpeech = ...
    enhancedFull(prefixSamples+1:end);

% Guarantee equal length
L = min( ...
    [length(cleanReference), ...
     length(noiseReference), ...
     length(enhancedSpeech)]);

cleanReference = cleanReference(1:L);
noiseReference = noiseReference(1:L);
enhancedSpeech = enhancedSpeech(1:L);

noisySpeech = ...
    cleanReference + noiseReference;

%% =========================================================
% SNR evaluation
%% =========================================================

inputSNR = ...
    10*log10( ...
        sum(cleanReference.^2) / ...
        sum(noiseReference.^2));

outputError = ...
    enhancedSpeech - cleanReference;

outputSNR = ...
    10*log10( ...
        sum(cleanReference.^2) / ...
        (sum(outputError.^2) + eps));

snrImprovement = ...
    outputSNR - inputSNR;

fprintf("===== BASIC SPECTRAL SUBTRACTION =====\n");

fprintf("Input SNR: %.3f dB\n", ...
    inputSNR);

fprintf("Output SNR: %.3f dB\n", ...
    outputSNR);

fprintf("SNR improvement: %.3f dB\n", ...
    snrImprovement);

fprintf("Gain range: %.3f to %.3f\n", ...
    min(result.gain(:)), ...
    max(result.gain(:)));

%% =========================================================
% Save enhanced audio
%% =========================================================

audioRoot = fullfile( ...
    projectRoot, ...
    "results", ...
    "audio");

if ~exist(audioRoot, "dir")
    mkdir(audioRoot);
end

[~, baseName, ~] = fileparts(files(1).name);

outputAudio = fullfile( ...
    audioRoot, ...
    baseName + "__basic_enhanced.wav");

%% Safe normalisation only for listening file

listenAudio = enhancedSpeech;

peak = max(abs(listenAudio));

if peak > 0.99
    listenAudio = ...
        listenAudio * (0.99/peak);
end

audiowrite( ...
    outputAudio, ...
    listenAudio, ...
    fs);

%% =========================================================
% Plot waveforms
%% =========================================================

t = (0:L-1)/fs;

figure;

subplot(3,1,1);

plot(t, cleanReference);

title("Clean Speech");
xlabel("Time (s)");
ylabel("Amplitude");
grid on;

subplot(3,1,2);

plot(t, noisySpeech);

title( ...
    sprintf( ...
    "Noisy Speech - Input SNR %.1f dB", ...
    inputSNR));

xlabel("Time (s)");
ylabel("Amplitude");
grid on;

subplot(3,1,3);

plot(t, enhancedSpeech);

title( ...
    sprintf( ...
    "Basic Spectral Subtraction - Output SNR %.2f dB", ...
    outputSNR));

xlabel("Time (s)");
ylabel("Amplitude");
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
        "basic_spectral_subtraction_waveforms.png"));

fprintf("\nEnhanced audio saved to:\n%s\n", ...
    outputAudio);

fprintf("\nDone.\n");