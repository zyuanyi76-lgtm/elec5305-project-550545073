clear;
clc;
close all;

%% Project path
projectRoot = "D:\课件\5305\elec5305-project-550545073";

noiseFile = fullfile(projectRoot, ...
    "data", "noise", "selected", ...
    "environmental_noise_16k.wav");

%% Read noise
[x, fs] = audioread(noiseFile);

if size(x,2) > 1
    x = mean(x,2);
end

%% Frame settings
frameDuration = 0.5;            % seconds
frameLength = round(frameDuration * fs);

numFrames = floor(length(x) / frameLength);

rmsValues = zeros(numFrames,1);

%% Calculate RMS for every 0.5 s frame
for i = 1:numFrames

    idx1 = (i-1)*frameLength + 1;
    idx2 = i*frameLength;

    frame = x(idx1:idx2);

    rmsValues(i) = sqrt(mean(frame.^2) + eps);
end

%% Convert to dB
rmsDb = 20*log10(rmsValues + eps);

timeAxis = ((1:numFrames)-0.5) * frameDuration;

%% Simple variation statistics
meanRmsDb = mean(rmsDb);
stdRmsDb = std(rmsDb);
rangeRmsDb = max(rmsDb) - min(rmsDb);

fprintf("===== ENVIRONMENTAL NOISE CHECK =====\n");
fprintf("Sample rate: %d Hz\n", fs);
fprintf("Duration: %.2f s\n", length(x)/fs);
fprintf("Mean frame RMS: %.2f dB\n", meanRmsDb);
fprintf("RMS standard deviation: %.2f dB\n", stdRmsDb);
fprintf("RMS range: %.2f dB\n", rangeRmsDb);

%% Plot RMS variation
figure;

plot(timeAxis, rmsDb, '-o');

xlabel('Time (s)');
ylabel('Frame RMS (dB)');
title('Environmental Noise RMS Variation');
grid on;

%% Save figure
figureRoot = fullfile(projectRoot, ...
    "results", "figures");

if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

saveas(gcf, fullfile(figureRoot, ...
    "environmental_noise_rms_variation.png"));

fprintf("\nFigure saved.\n");
fprintf("Done.\n");