clear;
clc;

%% Project paths
projectRoot = "D:\课件\5305\elec5305-project-550545073";

sourceRoot = fullfile(projectRoot, ...
    "data", "clean", "LibriSpeech", "test-clean");

outputRoot = fullfile(projectRoot, ...
    "data", "clean", "selected");

splitRoot = fullfile(projectRoot, ...
    "data", "splits");

if ~exist(outputRoot, "dir")
    mkdir(outputRoot);
end

if ~exist(splitRoot, "dir")
    mkdir(splitRoot);
end

%% Fixed speaker split
devSpeakers  = ["61", "121"];
testSpeakers = ["237", "260", "672", "908"];

%% Selection settings
minDuration = 3.0;   % seconds
maxDuration = 8.0;   % seconds
numPerSpeaker = 2;

%% Select development files
devFiles = selectFiles( ...
    sourceRoot, outputRoot, ...
    devSpeakers, minDuration, maxDuration, numPerSpeaker);

%% Select test files
testFiles = selectFiles( ...
    sourceRoot, outputRoot, ...
    testSpeakers, minDuration, maxDuration, numPerSpeaker);

%% Save split CSV files
devTable = table(devFiles, ...
    'VariableNames', {'filename'});

testTable = table(testFiles, ...
    'VariableNames', {'filename'});

writetable(devTable, ...
    fullfile(splitRoot, "dev_split.csv"));

writetable(testTable, ...
    fullfile(splitRoot, "test_split.csv"));

%% Display results
disp("Development set:");
disp(devTable);

disp("Test set:");
disp(testTable);

disp("Done.");

%% Local function
function selectedFiles = selectFiles( ...
    sourceRoot, outputRoot, speakerIDs, ...
    minDuration, maxDuration, numPerSpeaker)

selectedFiles = strings(0,1);

for s = 1:length(speakerIDs)

    speakerID = speakerIDs(s);

    speakerFolder = fullfile(sourceRoot, speakerID);

    files = dir(fullfile( ...
        speakerFolder, "**", "*.flac"));

    count = 0;

    for i = 1:length(files)

        inputFile = fullfile( ...
            files(i).folder, files(i).name);

        info = audioinfo(inputFile);

        duration = info.Duration;

        if duration >= minDuration && ...
                duration <= maxDuration

            outputFile = fullfile( ...
                outputRoot, files(i).name);

            copyfile(inputFile, outputFile);

            selectedFiles(end+1,1) = ...
                string(files(i).name);

            fprintf( ...
                "Speaker %s: %s (%.2f s)\n", ...
                speakerID, files(i).name, duration);

            count = count + 1;

            if count == numPerSpeaker
                break;
            end
        end
    end

    if count < numPerSpeaker
        warning( ...
            "Speaker %s has fewer than %d suitable files.", ...
            speakerID, numPerSpeaker);
    end
end
end