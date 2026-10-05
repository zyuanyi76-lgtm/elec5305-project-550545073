clear;
clc;

%% Project paths
projectRoot = "D:\课件\5305\elec5305-project-550545073";

cleanRoot = fullfile(projectRoot, ...
    "data", "clean", "selected");

splitRoot = fullfile(projectRoot, ...
    "data", "splits");

%% Read split files
devTable = readtable(fullfile(splitRoot, "dev_split.csv"), ...
    'TextType', 'string');

testTable = readtable(fullfile(splitRoot, "test_split.csv"), ...
    'TextType', 'string');

%% Add split labels
devTable.split = repmat("dev", height(devTable), 1);
testTable.split = repmat("test", height(testTable), 1);

allFiles = [devTable; testTable];

%% Metadata containers
n = height(allFiles);

speakerID = strings(n,1);
sampleRate = zeros(n,1);
channels = zeros(n,1);
duration_s = zeros(n,1);

%% Check each file
for i = 1:n

    filename = allFiles.filename(i);
    filePath = fullfile(cleanRoot, filename);

    info = audioinfo(filePath);

    sampleRate(i) = info.SampleRate;
    channels(i) = info.NumChannels;
    duration_s(i) = info.Duration;

    % Extract speaker ID from filename
    parts = split(filename, "-");
    speakerID(i) = parts(1);

    fprintf( ...
        "%s | split=%s | speaker=%s | fs=%d Hz | channels=%d | duration=%.2f s\n", ...
        filename, ...
        allFiles.split(i), ...
        speakerID(i), ...
        sampleRate(i), ...
        channels(i), ...
        duration_s(i));
end

%% Create metadata table
metadata = table( ...
    allFiles.filename, ...
    allFiles.split, ...
    speakerID, ...
    sampleRate, ...
    channels, ...
    duration_s, ...
    'VariableNames', ...
    {'filename','split','speaker','sample_rate_hz','channels','duration_s'});

%% Save metadata
writetable(metadata, ...
    fullfile(splitRoot, "clean_metadata.csv"));

%% Validation
fprintf("\n===== DATASET CHECK =====\n");

if all(sampleRate == 16000)
    fprintf("PASS: All files are 16 kHz.\n");
else
    warning("Some files are not 16 kHz.");
end

if all(channels == 1)
    fprintf("PASS: All files are mono.\n");
else
    warning("Some files are not mono.");
end

if all(duration_s >= 3 & duration_s <= 8)
    fprintf("PASS: All files are between 3 and 8 seconds.\n");
else
    warning("Some files are outside the 3-8 second duration range.");
end

fprintf("Development utterances: %d\n", sum(allFiles.split == "dev"));
fprintf("Test utterances: %d\n", sum(allFiles.split == "test"));
fprintf("Total utterances: %d\n", n);

fprintf("\nDone.\n");