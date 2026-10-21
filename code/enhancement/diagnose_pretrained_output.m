
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Pretrained Model Output Diagnostics
% Development data only
% Check latency, amplitude, SNR and STOI
%% =========================================================

%% Project paths

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

modelRoot = fullfile(projectRoot, ...
    "external", "enhanceSpeechModel");

addpath(genpath(modelRoot));

devRoot = fullfile(projectRoot, ...
    "data", "mixtures", "dev");

%% Load one development example

files = dir(fullfile(devRoot, ...
    "*__environmental__10dB.mat"));

if isempty(files)
    error("No matching development file found.");
end

data = load(fullfile(files(1).folder, files(1).name));

if string(data.splitName) ~= "dev"
    error("Expected development data.");
end

fs = data.fs;

clean = double(data.cleanReference(:));
noisy = double(data.noisySpeech(:));

%% Run pretrained model

enhanced = double(enhanceSpeech(noisy, fs));
enhanced = enhanced(:);

if length(enhanced) ~= length(clean)
    error("Unexpected output length.");
end

%% Original evaluation

rawError = enhanced - clean;

rawSNR = 10*log10( ...
    sum(clean.^2) / (sum(rawError.^2) + eps));

rawSTOI = stoi(enhanced, clean, fs);

%% Detect delay using noisy input
% No clean reference is used to estimate delay.

maxLag = round(0.1 * fs);

[correlation, lags] = xcorr( ...
    enhanced, noisy, maxLag, 'coeff');

[peakCorrelation, idx] = max(correlation);

estimatedLag = lags(idx);

%% Align using the input-output delay

if estimatedLag > 0

    aligned = enhanced(estimatedLag+1:end);
    alignedClean = clean(1:end-estimatedLag);

elseif estimatedLag < 0

    advance = -estimatedLag;

    aligned = enhanced(1:end-advance);
    alignedClean = clean(advance+1:end);

else

    aligned = enhanced;
    alignedClean = clean;

end

%% Evaluate delay-corrected signal

alignedError = aligned - alignedClean;

alignedSNR = 10*log10( ...
    sum(alignedClean.^2) / ...
    (sum(alignedError.^2) + eps));

alignedSTOI = stoi(aligned, alignedClean, fs);

%% Amplitude diagnostics

rmsClean = sqrt(mean(clean.^2));
rmsNoisy = sqrt(mean(noisy.^2));
rmsEnhanced = sqrt(mean(enhanced.^2));

rmsRatio = rmsEnhanced / max(rmsClean, eps);

%% Oracle amplitude correction
% Diagnostic only: not a deployable correction.

oracleGain = ...
    sum(aligned .* alignedClean) / ...
    max(sum(aligned.^2), eps);

oracleScaled = aligned * oracleGain;

oracleError = oracleScaled - alignedClean;

oracleScaledSNR = 10*log10( ...
    sum(alignedClean.^2) / ...
    (sum(oracleError.^2) + eps));

%% Print results

fprintf("\n===== PRETRAINED MODEL DIAGNOSTICS =====\n");

fprintf("File: %s\n", files(1).name);

fprintf("\n===== AMPLITUDE =====\n");

fprintf("Clean RMS: %.6f\n", rmsClean);
fprintf("Noisy RMS: %.6f\n", rmsNoisy);
fprintf("Enhanced RMS: %.6f\n", rmsEnhanced);
fprintf("Enhanced/Clean RMS ratio: %.4f\n", rmsRatio);

fprintf("\n===== TIME ALIGNMENT =====\n");

fprintf("Estimated lag: %d samples\n", estimatedLag);

fprintf("Estimated lag: %.3f ms\n", ...
    1000*estimatedLag/fs);

fprintf("Peak correlation: %.4f\n", peakCorrelation);

fprintf("\n===== RAW METRICS =====\n");

fprintf("SNR: %.4f dB\n", rawSNR);
fprintf("STOI: %.4f\n", rawSTOI);

fprintf("\n===== DELAY-CORRECTED METRICS =====\n");

fprintf("SNR: %.4f dB\n", alignedSNR);
fprintf("STOI: %.4f\n", alignedSTOI);

fprintf("\n===== ORACLE AMPLITUDE DIAGNOSTIC =====\n");

fprintf("Oracle gain: %.4f\n", oracleGain);

fprintf("SNR after oracle scaling: %.4f dB\n", ...
    oracleScaledSNR);

fprintf("\nDone.\n");
