clear;
clc;

%% =========================================================
%  ELEC5305 - Generate controlled noisy speech mixtures
%  12 utterances x 2 noise types x 3 SNRs = 72 mixtures
% ==========================================================

%% Project paths
projectRoot = "D:\课件\5305\elec5305-project-550545073";

cleanRoot = fullfile(projectRoot, ...
    "data", "clean", "selected");

splitRoot = fullfile(projectRoot, ...
    "data", "splits");

mixtureRoot = fullfile(projectRoot, ...
    "data", "mixtures");

envNoiseFile = fullfile(projectRoot, ...
    "data", "noise", "selected", ...
    "environmental_noise_16k.wav");

%% Output folders
devOutput = fullfile(mixtureRoot, "dev");
testOutput = fullfile(mixtureRoot, "test");

if ~exist(devOutput, "dir")
    mkdir(devOutput);
end

if ~exist(testOutput, "dir")
    mkdir(testOutput);
end

%% Fixed experimental settings
targetFs = 16000;

snrLevels = [0 5 10];

noiseTypes = ["white", "environmental"];

prefixDuration = 0.5;                % seconds
prefixSamples = round(prefixDuration * targetFs);

%% Read fixed development / test splits
devTable = readtable( ...
    fullfile(splitRoot, "dev_split.csv"), ...
    'TextType', 'string');

testTable = readtable( ...
    fullfile(splitRoot, "test_split.csv"), ...
    'TextType', 'string');

devTable.split = repmat("dev", height(devTable), 1);
testTable.split = repmat("test", height(testTable), 1);

allTable = [devTable; testTable];

%% Read environmental noise
[envNoise, envFs] = audioread(envNoiseFile);

if size(envNoise,2) > 1
    envNoise = mean(envNoise,2);
end

if envFs ~= targetFs
    envNoise = resample(envNoise, targetFs, envFs);
end

envNoise = envNoise - mean(envNoise);

%% Metadata storage
metaFilename = strings(0,1);
metaSplit = strings(0,1);
metaSpeaker = strings(0,1);
metaNoiseType = strings(0,1);

metaTargetSnr = [];
metaAchievedSnr = [];
metaDuration = [];
metaSafetyGain = [];
metaEnvStart = [];

%% =========================================================
% Generate mixtures
%% =========================================================

mixtureCounter = 0;

for u = 1:height(allTable)

    cleanFilename = allTable.filename(u);
    splitName = allTable.split(u);

    cleanPath = fullfile(cleanRoot, cleanFilename);

    %% Read clean speech
    [clean, fs] = audioread(cleanPath);

    if size(clean,2) > 1
        clean = mean(clean,2);
    end

    if fs ~= targetFs
        clean = resample(clean, targetFs, fs);
        fs = targetFs;
    end

    clean = clean - mean(clean);

    cleanLength = length(clean);

    %% Speaker ID
    parts = split(cleanFilename, "-");
    speakerID = parts(1);

    %% Remove extension for output name
    [~, cleanBase, ~] = fileparts(cleanFilename);

    %% Required noise length
    totalNoiseLength = prefixSamples + cleanLength;

    %% =====================================================
    % Prepare one WHITE noise realization for this utterance
    % Same realization is reused for 0/5/10 dB
    %% =====================================================

    rng(1000 + u, 'twister');

    whiteFull = randn(totalNoiseLength, 1);
    whiteFull = whiteFull - mean(whiteFull);

    %% =====================================================
    % Prepare one ENVIRONMENTAL segment for this utterance
    % Same segment is reused for 0/5/10 dB
    %% =====================================================

    maxStart = length(envNoise) - totalNoiseLength + 1;

    if maxStart < 1
        error("Environmental noise is too short.");
    end

    % Deterministic offset for reproducibility
    stepSamples = round(2.0 * targetFs);

    envStart = 1 + mod((u-1)*stepSamples, maxStart);

    envFull = envNoise( ...
        envStart : envStart + totalNoiseLength - 1);

    envFull = envFull - mean(envFull);

    %% =====================================================
    % Loop over noise types
    %% =====================================================

    for nt = 1:length(noiseTypes)

        noiseType = noiseTypes(nt);

        if noiseType == "white"

            rawFullNoise = whiteFull;
            envStartSeconds = NaN;

        else

            rawFullNoise = envFull;
            envStartSeconds = (envStart - 1) / targetFs;

        end

        %% Split noise into prefix and speech region
        rawPrefix = rawFullNoise(1:prefixSamples);

        rawSpeechNoise = rawFullNoise( ...
            prefixSamples+1:end);

        %% Clean signal power
        cleanPower = mean(clean.^2);

        %% Raw noise power over speech region
        noisePower = mean(rawSpeechNoise.^2);

        if cleanPower <= 0 || noisePower <= 0
            error("Invalid clean/noise power.");
        end

        %% =================================================
        % Loop over target SNR
        %% =================================================

        for s = 1:length(snrLevels)

            targetSNR = snrLevels(s);

            %% Required noise scaling
            noiseScale = sqrt( ...
                cleanPower / ...
                (noisePower * 10^(targetSNR/10)));

            noisePrefix = rawPrefix * noiseScale;

            noiseSpeech = rawSpeechNoise * noiseScale;

            %% Speech-region mixture
            noisySpeech = clean + noiseSpeech;

            %% Full waveform includes 0.5 s noise-only prefix
            fullNoisy = [noisePrefix; noisySpeech];

            %% =================================================
            % Prevent WAV clipping
            % Apply SAME safety gain to all diagnostic components
            %% =================================================

            peakValue = max(abs(fullNoisy));

            if peakValue > 0.99
                safetyGain = 0.99 / peakValue;
            else
                safetyGain = 1.0;
            end

            fullNoisy = fullNoisy * safetyGain;

            cleanReference = clean * safetyGain;
            noiseReference = noiseSpeech * safetyGain;
            noisePrefix = noisePrefix * safetyGain;
            noisySpeech = noisySpeech * safetyGain;

            %% Verify achieved SNR on speech region
            achievedSNR = 10*log10( ...
                sum(cleanReference.^2) / ...
                sum(noiseReference.^2));

            %% Output folder
            if splitName == "dev"
                outputFolder = devOutput;
            else
                outputFolder = testOutput;
            end

            %% Output base name
            outputBase = sprintf( ...
                "%s__%s__%ddB", ...
                cleanBase, ...
                char(noiseType), ...
                targetSNR);

            wavFile = fullfile( ...
                outputFolder, outputBase + ".wav");

            matFile = fullfile( ...
                outputFolder, outputBase + ".mat");

            %% Save noisy WAV
            audiowrite( ...
                wavFile, ...
                fullNoisy, ...
                targetFs);

            %% Save exact components for later evaluation
            fs = targetFs;

            save(matFile, ...
                "cleanReference", ...
                "noiseReference", ...
                "noisePrefix", ...
                "noisySpeech", ...
                "fullNoisy", ...
                "fs", ...
                "targetSNR", ...
                "achievedSNR", ...
                "safetyGain", ...
                "noiseType", ...
                "splitName", ...
                "speakerID", ...
                "cleanFilename");

            %% Metadata
            mixtureCounter = mixtureCounter + 1;

            metaFilename(mixtureCounter,1) = ...
                string(outputBase + ".wav");

            metaSplit(mixtureCounter,1) = splitName;

            metaSpeaker(mixtureCounter,1) = speakerID;

            metaNoiseType(mixtureCounter,1) = noiseType;

            metaTargetSnr(mixtureCounter,1) = targetSNR;

            metaAchievedSnr(mixtureCounter,1) = achievedSNR;

            metaDuration(mixtureCounter,1) = ...
                length(cleanReference)/targetFs;

            metaSafetyGain(mixtureCounter,1) = ...
                safetyGain;

            metaEnvStart(mixtureCounter,1) = ...
                envStartSeconds;

            %% Display
            fprintf( ...
                "%3d | %-4s | speaker=%s | %-13s | target=%2d dB | achieved=%6.3f dB\n", ...
                mixtureCounter, ...
                splitName, ...
                speakerID, ...
                noiseType, ...
                targetSNR, ...
                achievedSNR);
        end
    end
end

%% =========================================================
% Save metadata CSV
%% =========================================================

metadata = table( ...
    metaFilename, ...
    metaSplit, ...
    metaSpeaker, ...
    metaNoiseType, ...
    metaTargetSnr, ...
    metaAchievedSnr, ...
    metaDuration, ...
    metaSafetyGain, ...
    metaEnvStart, ...
    'VariableNames', { ...
    'filename', ...
    'split', ...
    'speaker', ...
    'noise_type', ...
    'target_snr_db', ...
    'achieved_snr_db', ...
    'speech_duration_s', ...
    'safety_gain', ...
    'environmental_start_s'});

metadataFile = fullfile( ...
    mixtureRoot, ...
    "mixture_metadata.csv");

writetable(metadata, metadataFile);

%% =========================================================
% Final validation
%% =========================================================

fprintf("\n===== MIXTURE GENERATION CHECK =====\n");

fprintf("Development mixtures: %d\n", ...
    sum(metadata.split == "dev"));

fprintf("Test mixtures: %d\n", ...
    sum(metadata.split == "test"));

fprintf("Total mixtures: %d\n", ...
    height(metadata));

maxSnrError = max(abs( ...
    metadata.target_snr_db - ...
    metadata.achieved_snr_db));

fprintf("Maximum SNR error: %.6f dB\n", ...
    maxSnrError);

if height(metadata) == 72
    fprintf("PASS: Correct number of mixtures.\n");
else
    warning("Incorrect number of mixtures.");
end

if maxSnrError < 0.01
    fprintf("PASS: All target SNR values verified.\n");
else
    warning("Some SNR values are inaccurate.");
end

fprintf("\nMetadata saved to:\n%s\n", ...
    metadataFile);

fprintf("\nDone.\n");