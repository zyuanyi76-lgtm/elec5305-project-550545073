
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Pretrained Speech Enhancement Comparison
% 48 held-out test mixtures
% MATLAB Audio Toolbox enhanceSpeech
%% =========================================================

%% Project paths

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

addpath(fullfile(projectRoot, "code", "enhancement"));

modelRoot = fullfile(projectRoot, ...
    "external", "enhanceSpeechModel");

addpath(genpath(modelRoot));

testRoot = fullfile(projectRoot, ...
    "data", "mixtures", "test");

metricsRoot = fullfile(projectRoot, ...
    "results", "metrics");

figureRoot = fullfile(projectRoot, ...
    "results", "figures");

audioRoot = fullfile(projectRoot, ...
    "results", "audio", "modern_model");

if ~exist(metricsRoot, "dir")
    mkdir(metricsRoot);
end

if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

if ~exist(audioRoot, "dir")
    mkdir(audioRoot);
end

%% Load test mixtures

files = dir(fullfile(testRoot, "*.mat"));

numFiles = numel(files);

if numFiles ~= 48
    error("Expected 48 held-out test mixtures.");
end

%% Allocate result arrays

fileNames = strings(numFiles, 1);
noiseTypes = strings(numFiles, 1);

targetSNRs = zeros(numFiles, 1);

inputSNRs = zeros(numFiles, 1);
outputSNRs = zeros(numFiles, 1);
snrImprovements = zeros(numFiles, 1);

inputSTOIs = zeros(numFiles, 1);
outputSTOIs = zeros(numFiles, 1);
stoiImprovements = zeros(numFiles, 1);

processingTimes = zeros(numFiles, 1);

%% Fixed listening example

demoFilename = ...
    "237-126133-0003__environmental__0dB.mat";

fprintf("===== PRETRAINED MODEL EVALUATION =====\n");
fprintf("Test mixtures: %d\n", numFiles);
fprintf("Model: MATLAB enhanceSpeech\n");
fprintf("Parameter tuning: None\n\n");

tic;

%% =========================================================
% Process all 48 held-out test mixtures
%% =========================================================

for i = 1:numFiles

    data = load(fullfile( ...
        files(i).folder, files(i).name));

    %% Validate test data

    if string(data.splitName) ~= "test"
        error("Development mixture detected.");
    end

    fs = data.fs;

    if fs ~= 16000
        error("Expected 16 kHz sampling rate.");
    end

    clean = double(data.cleanReference(:));
    noise = double(data.noiseReference(:));

    noisy = double(data.noisySpeech(:));

    if numel(noisy) ~= numel(clean)
        error("Input length mismatch.");
    end

    mixtureError = max(abs(noisy - (clean + noise)));

    if mixtureError > 1e-9
        error("Stored mixture components are inconsistent.");
    end

    %% Pretrained enhancement

    startTime = tic;

    enhanced = enhanceSpeech(noisy, fs);

    processingTimes(i) = toc(startTime);

    enhanced = double(enhanced(:));

    if numel(enhanced) ~= numel(clean)
        error("Model output length mismatch.");
    end

    if any(~isfinite(enhanced))
        error("Model output contains invalid values.");
    end

    %% Reference-based input SNR

    inputSNR = 10*log10( ...
        sum(clean.^2) / ...
        (sum(noise.^2) + eps));

    %% Reference-based output SNR

    outputError = enhanced - clean;

    outputSNR = 10*log10( ...
        sum(clean.^2) / ...
        (sum(outputError.^2) + eps));

    snrGain = outputSNR - inputSNR;

    %% STOI evaluation

    inputSTOI = stoi(noisy, clean, fs);

    outputSTOI = stoi(enhanced, clean, fs);

    stoiGain = outputSTOI - inputSTOI;

    %% Store metrics

    fileNames(i) = string(files(i).name);

    noiseTypes(i) = string(data.noiseType);

    targetSNRs(i) = data.targetSNR;

    inputSNRs(i) = inputSNR;
    outputSNRs(i) = outputSNR;
    snrImprovements(i) = snrGain;

    inputSTOIs(i) = inputSTOI;
    outputSTOIs(i) = outputSTOI;
    stoiImprovements(i) = stoiGain;

    %% Save one representative audio example

    if string(files(i).name) == demoFilename

        signals = {clean, noisy, enhanced};

        peakValue = max([ ...
            max(abs(clean)), ...
            max(abs(noisy)), ...
            max(abs(enhanced))]);

        commonGain = min(1, 0.99/max(peakValue, eps));

        names = [
            "01_clean.wav"
            "02_noisy.wav"
            "03_pretrained_enhanced.wav"
        ];

        for k = 1:3

            audiowrite( ...
                fullfile(audioRoot, names(k)), ...
                signals{k} * commonGain, fs);

        end

    end

    fprintf( ...
        "%2d/%2d | SNR gain %7.3f dB | STOI %.4f | %.2f s\n", ...
        i, numFiles, snrGain, outputSTOI, ...
        processingTimes(i));

end

totalTime = toc;

%% =========================================================
% Save detailed model metrics
%% =========================================================

modelResults = table( ...
    fileNames, noiseTypes, targetSNRs, ...
    inputSNRs, outputSNRs, snrImprovements, ...
    inputSTOIs, outputSTOIs, stoiImprovements, ...
    processingTimes, ...
    'VariableNames', { ...
    'filename', 'noise_type', 'target_snr_db', ...
    'input_snr_db', 'output_snr_db', ...
    'snr_improvement_db', ...
    'input_stoi', 'output_stoi', ...
    'stoi_improvement', 'processing_time_s'});

writetable(modelResults, ...
    fullfile(metricsRoot, ...
    "pretrained_model_test_detailed.csv"));

%% =========================================================
% Load previous classical-method test results
%% =========================================================

referenceFile = fullfile(metricsRoot, ...
    "test_detailed_metrics.csv");

if ~isfile(referenceFile)
    error("Previous test metrics CSV was not found.");
end

reference = readtable(referenceFile, ...
    'TextType', 'string');

methodNames = [
    "Basic"
    "SNR_focused"
    "STOI_focused"
    "Aggressive_diagnostic"
    "MATLAB_enhanceSpeech"
];

numMethods = numel(methodNames);

meanSNR = zeros(numMethods, 1);
meanSTOI = zeros(numMethods, 1);
meanSTOIGain = zeros(numMethods, 1);

%% Classical methods

for m = 1:4

    selected = reference.method == methodNames(m);

    if sum(selected) ~= 48
        error("Incomplete previous test results.");
    end

    meanSNR(m) = mean( ...
        reference.snr_improvement_db(selected));

    meanSTOI(m) = mean( ...
        reference.output_stoi(selected));

    meanSTOIGain(m) = mean( ...
        reference.stoi_improvement(selected));

end

%% Pretrained model

meanSNR(5) = mean(snrImprovements);
meanSTOI(5) = mean(outputSTOIs);
meanSTOIGain(5) = mean(stoiImprovements);

comparisonTable = table( ...
    methodNames, meanSNR, meanSTOI, meanSTOIGain, ...
    'VariableNames', { ...
    'method', ...
    'mean_snr_improvement_db', ...
    'mean_output_stoi', ...
    'mean_stoi_improvement'});

writetable(comparisonTable, ...
    fullfile(metricsRoot, ...
    "classical_vs_pretrained_summary.csv"));

%% =========================================================
% Paired comparison with Basic
%% =========================================================

basicRows = reference.method == "Basic";

basicTable = reference(basicRows, :);

[matched, locations] = ismember( ...
    fileNames, basicTable.filename);

if ~all(matched)
    error("Could not match all pretrained and Basic results.");
end

pairedSNR = snrImprovements - ...
    basicTable.snr_improvement_db(locations);

pairedSTOI = outputSTOIs - ...
    basicTable.output_stoi(locations);

fprintf("\n===== PAIRED COMPARISON VS BASIC =====\n");

fprintf("Mean SNR difference: %.4f dB\n", ...
    mean(pairedSNR));

fprintf("Mean STOI difference: %.5f\n", ...
    mean(pairedSTOI));

fprintf("SNR better count: %d/48\n", ...
    sum(pairedSNR > 0));

fprintf("STOI better count: %d/48\n", ...
    sum(pairedSTOI > 0));

pairedTable = table( ...
    fileNames, pairedSNR, pairedSTOI, ...
    'VariableNames', { ...
    'filename', ...
    'snr_difference_vs_basic_db', ...
    'stoi_difference_vs_basic'});

writetable(pairedTable, ...
    fullfile(metricsRoot, ...
    "pretrained_vs_basic_paired.csv"));

%% =========================================================
% Model performance by noise type and input SNR
%% =========================================================

noiseGrid = ["white"; "environmental"];
snrGrid = [0; 5; 10];

conditionNoise = strings(6,1);
conditionSNR = zeros(6,1);
conditionCount = zeros(6,1);
conditionSNRGain = zeros(6,1);
conditionSTOI = zeros(6,1);

row = 0;

for n = 1:2

    for s = 1:3

        selected = ...
            noiseTypes == noiseGrid(n) & ...
            targetSNRs == snrGrid(s);

        row = row + 1;

        conditionNoise(row) = noiseGrid(n);
        conditionSNR(row) = snrGrid(s);
        conditionCount(row) = sum(selected);

        if conditionCount(row) ~= 8
            error("Unexpected number of condition samples.");
        end

        conditionSNRGain(row) = ...
            mean(snrImprovements(selected));

        conditionSTOI(row) = ...
            mean(outputSTOIs(selected));

    end
end

conditionTable = table( ...
    conditionNoise, conditionSNR, ...
    conditionCount, conditionSNRGain, conditionSTOI, ...
    'VariableNames', { ...
    'noise_type', 'target_snr_db', ...
    'sample_count', ...
    'mean_snr_improvement_db', ...
    'mean_output_stoi'});

writetable(conditionTable, ...
    fullfile(metricsRoot, ...
    "pretrained_model_condition_summary.csv"));

%% =========================================================
% Print final summary
%% =========================================================

fprintf("\n===== CLASSICAL VS PRETRAINED =====\n");

disp(comparisonTable);

fprintf("\n===== PRETRAINED BY CONDITION =====\n");

disp(conditionTable);

fprintf("\n===== MODEL PROCESSING =====\n");

fprintf("Total processing time: %.2f s\n", totalTime);
fprintf("Mean inference time: %.2f s\n", ...
    mean(processingTimes));

%% =========================================================
% Plot model comparison
%% =========================================================

figure('Position', [100, 150, 1250, 480]);

tiledlayout(1,2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

nexttile;

bar(meanSNR);

xticks(1:numMethods);
xticklabels(methodNames);
xtickangle(25);

ylabel("Mean SNR Improvement (dB)");
title("Reference-Based SNR Improvement");
grid on;

nexttile;

bar(meanSTOI);

xticks(1:numMethods);
xticklabels(methodNames);
xtickangle(25);

ylabel("Mean Output STOI");
title("Speech Intelligibility");
grid on;

sgtitle("Held-Out Test - Classical vs Pretrained Enhancement");

exportgraphics(gcf, ...
    fullfile(figureRoot, ...
    "classical_vs_pretrained_comparison.png"), ...
    'Resolution', 200);

fprintf("\n===== OUTPUT FILES =====\n");

fprintf("pretrained_model_test_detailed.csv\n");
fprintf("classical_vs_pretrained_summary.csv\n");
fprintf("pretrained_vs_basic_paired.csv\n");
fprintf("pretrained_model_condition_summary.csv\n");
fprintf("classical_vs_pretrained_comparison.png\n");

fprintf("\nDone.\n");
