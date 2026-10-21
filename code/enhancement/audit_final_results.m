
clear;
clc;
close all;

%% =========================================================
% ELEC5305 - Final Results Audit
% Validate datasets, metrics, and output files
%% =========================================================

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));

devRoot = fullfile(projectRoot, ...
    "data", "mixtures", "dev");

testRoot = fullfile(projectRoot, ...
    "data", "mixtures", "test");

metricsRoot = fullfile(projectRoot, ...
    "results", "metrics");

figureRoot = fullfile(projectRoot, ...
    "results", "figures");

%% =========================================================
% 1. Dataset integrity
%% =========================================================

fprintf("===== DATASET AUDIT =====\n");

devFiles = dir(fullfile(devRoot, "*.mat"));
testFiles = dir(fullfile(testRoot, "*.mat"));

assert(numel(devFiles) == 24, ...
    "Development mixture count mismatch.");

assert(numel(testFiles) == 48, ...
    "Test mixture count mismatch.");

devSpeakers = strings(numel(devFiles), 1);
testSpeakers = strings(numel(testFiles), 1);

for i = 1:numel(devFiles)

    d = load(fullfile( ...
        devFiles(i).folder, devFiles(i).name));

    assert(string(d.splitName) == "dev");

    devSpeakers(i) = string(d.speakerID);

end

for i = 1:numel(testFiles)

    d = load(fullfile( ...
        testFiles(i).folder, testFiles(i).name));

    assert(string(d.splitName) == "test");

    testSpeakers(i) = string(d.speakerID);

end

sharedSpeakers = intersect( ...
    unique(devSpeakers), unique(testSpeakers));

assert(isempty(sharedSpeakers), ...
    "Speaker leakage detected between data splits.");

fprintf("Development mixtures: %d\n", numel(devFiles));
fprintf("Test mixtures: %d\n", numel(testFiles));

fprintf("Development speakers: %d\n", ...
    numel(unique(devSpeakers)));

fprintf("Test speakers: %d\n", ...
    numel(unique(testSpeakers)));

fprintf("PASS: No shared speakers between splits.\n");

%% =========================================================
% 2. Load evaluation CSV files
%% =========================================================

fprintf("\n===== METRIC FILE AUDIT =====\n");

classical = readtable(fullfile(metricsRoot, ...
    "test_detailed_metrics.csv"), ...
    'TextType', 'string');

modern = readtable(fullfile(metricsRoot, ...
    "pretrained_model_test_detailed.csv"), ...
    'TextType', 'string');

overall = readtable(fullfile(metricsRoot, ...
    "test_overall_summary.csv"), ...
    'TextType', 'string');

comparison = readtable(fullfile(metricsRoot, ...
    "classical_vs_pretrained_summary.csv"), ...
    'TextType', 'string');

assert(height(classical) == 192, ...
    "Classical evaluation count mismatch.");

assert(height(modern) == 48, ...
    "Pretrained evaluation count mismatch.");

assert(height(overall) == 4, ...
    "Classical summary count mismatch.");

assert(height(comparison) == 5, ...
    "Combined summary count mismatch.");

assert(numel(unique(string(modern.filename))) == 48, ...
    "Duplicate pretrained filenames detected.");

%% =========================================================
% 3. Verify metric calculations
%% =========================================================

snrError = max(abs( ...
    modern.output_snr_db - modern.input_snr_db ...
    - modern.snr_improvement_db));

stoiError = max(abs( ...
    modern.output_stoi - modern.input_stoi ...
    - modern.stoi_improvement));

assert(snrError < 1e-5, ...
    "Pretrained SNR consistency check failed.");

assert(stoiError < 1e-5, ...
    "Pretrained STOI consistency check failed.");

fprintf("PASS: Pretrained metric calculations.\n");

%% =========================================================
% 4. Verify matched test files
%% =========================================================

basic = classical( ...
    string(classical.method) == "Basic", :);

assert(height(basic) == 48, ...
    "Basic evaluation count mismatch.");

[matched, idx] = ismember( ...
    string(modern.filename), ...
    string(basic.filename));

assert(all(matched), ...
    "Unmatched pretrained test files detected.");

basic = basic(idx, :);

assert(all( ...
    string(modern.noise_type) == ...
    string(basic.noise_type)), ...
    "Noise condition mismatch.");

assert(all( ...
    modern.target_snr_db == basic.target_snr_db), ...
    "Target SNR mismatch.");

inputDifference = max(abs( ...
    modern.input_snr_db - basic.input_snr_db));

assert(inputDifference < 1e-5, ...
    "Input SNR mismatch between methods.");

fprintf("PASS: All 48 test mixtures are paired.\n");

%% =========================================================
% 5. Verify final method averages
%% =========================================================

methodNames = [
    "Basic"
    "SNR_focused"
    "STOI_focused"
    "Aggressive_diagnostic"
    "MATLAB_enhanceSpeech"
];

calculatedSNR = zeros(5,1);
calculatedSTOI = zeros(5,1);

for k = 1:4

    selected = ...
        string(classical.method) == methodNames(k);

    assert(sum(selected) == 48, ...
        "Incomplete classical method results.");

    calculatedSNR(k) = mean( ...
        classical.snr_improvement_db(selected));

    calculatedSTOI(k) = mean( ...
        classical.output_stoi(selected));

end

calculatedSNR(5) = mean(modern.snr_improvement_db);
calculatedSTOI(5) = mean(modern.output_stoi);

for k = 1:5

    selected = ...
        string(comparison.method) == methodNames(k);

    assert(sum(selected) == 1, ...
        "Combined summary method mismatch.");

    assert(abs( ...
        comparison.mean_snr_improvement_db(selected) ...
        - calculatedSNR(k)) < 1e-4, ...
        "Summary SNR mismatch.");

    assert(abs( ...
        comparison.mean_output_stoi(selected) ...
        - calculatedSTOI(k)) < 1e-5, ...
        "Summary STOI mismatch.");

end

fprintf("PASS: Final method averages are consistent.\n");

%% =========================================================
% 6. Print verified results
%% =========================================================

verifiedTable = table( ...
    methodNames, calculatedSNR, calculatedSTOI, ...
    'VariableNames', { ...
    'method', ...
    'mean_snr_improvement_db', ...
    'mean_output_stoi'});

fprintf("\n===== VERIFIED FINAL RESULTS =====\n");

disp(verifiedTable);

fprintf("\n===== PRETRAINED VS BASIC =====\n");

fprintf("Mean SNR difference: %.4f dB\n", ...
    mean(modern.snr_improvement_db ...
    - basic.snr_improvement_db));

fprintf("Mean STOI difference: %.5f\n", ...
    mean(modern.output_stoi ...
    - basic.output_stoi));

%% =========================================================
% 7. Check output figures
%% =========================================================

fprintf("\n===== FIGURE AUDIT =====\n");

figureNames = [
    "alpha_beta_snr_heatmaps.png"
    "alpha_beta_stoi_heatmaps.png"
    "snr_stoi_tradeoff.png"
    "speech_noise_tradeoff.png"
    "final_test_comparison.png"
    "final_test_paired_differences.png"
    "final_spectrogram_comparison.png"
    "oracle_phase_comparison.png"
    "oracle_phase_spectrogram_demo.png"
    "classical_vs_pretrained_comparison.png"
];

missingFigures = strings(0,1);

for i = 1:numel(figureNames)

    figurePath = fullfile( ...
        figureRoot, figureNames(i));

    if isfile(figurePath)

        fprintf("PASS: %s\n", figureNames(i));

    else

        fprintf("MISSING: %s\n", figureNames(i));

        missingFigures(end+1,1) = figureNames(i);

    end
end

%% =========================================================
% 8. Final status
%% =========================================================

fprintf("\n===== FINAL AUDIT SUMMARY =====\n");

fprintf("Dataset integrity: PASS\n");
fprintf("Speaker separation: PASS\n");
fprintf("Metric consistency: PASS\n");
fprintf("Paired comparisons: PASS\n");
fprintf("Summary consistency: PASS\n");

fprintf("Figures found: %d/%d\n", ...
    numel(figureNames)-numel(missingFigures), ...
    numel(figureNames));

if isempty(missingFigures)
    fprintf("PASS: All expected figures exist.\n");
else
    fprintf("CHECK: Some figures are missing.\n");
end

fprintf("\nAudit completed.\n");
