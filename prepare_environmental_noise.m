clear;
clc;

%% Project path
projectRoot = "D:\课件\5305\elec5305-project-550545073";

noiseRoot = fullfile(projectRoot, ...
    "data", "noise", "selected");

%% Input file
inputFile = fullfile(noiseRoot, ...
    "environmental_noise.m4a");

%% Output file
outputFile = fullfile(noiseRoot, ...
    "environmental_noise_16k.wav");

%% Read audio
[x, fs] = audioread(inputFile);

fprintf("Original sample rate: %d Hz\n", fs);
fprintf("Original channels: %d\n", size(x,2));
fprintf("Original duration: %.2f s\n", length(x)/fs);

%% Convert stereo to mono
if size(x,2) > 1
    x = mean(x,2);
end

%% Resample to 16 kHz
targetFs = 16000;

if fs ~= targetFs
    x = resample(x, targetFs, fs);
end

%% Remove DC offset
x = x - mean(x);

%% Safe normalization
x = x / (max(abs(x)) + eps) * 0.95;

%% Save WAV
audiowrite(outputFile, x, targetFs);

fprintf("\n===== OUTPUT =====\n");
fprintf("Sample rate: %d Hz\n", targetFs);
fprintf("Channels: 1\n");
fprintf("Duration: %.2f s\n", length(x)/targetFs);
fprintf("Saved to:\n%s\n", outputFile);

fprintf("\nDone.\n");