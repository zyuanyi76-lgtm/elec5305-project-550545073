function y = stft_synthesis_custom(X, info)

winLength = info.winLength;
hopSize = info.hopSize;
nfft = info.nfft;
window = info.window;

numFrames = size(X,2);

outputLength = ...
    (numFrames - 1)*hopSize + winLength;

% Overlap-add buffers
yPad = zeros(outputLength,1);

windowSum = zeros(outputLength,1);

for m = 1:numFrames

    idx1 = (m-1)*hopSize + 1;
    idx2 = idx1 + winLength - 1;

    % IFFT
    frame = real(ifft(X(:,m), nfft));

    % nfft = winLength here
    frame = frame(1:winLength);

    % Synthesis window
    frame = frame .* window;

    % Overlap-add
    yPad(idx1:idx2) = ...
        yPad(idx1:idx2) + frame;

    % Window-power normalisation
    windowSum(idx1:idx2) = ...
        windowSum(idx1:idx2) + window.^2;
end

%% Normalise overlapping windows

valid = windowSum > 1e-12;

yPad(valid) = ...
    yPad(valid) ./ windowSum(valid);

%% Remove padding

startIndex = info.padLength + 1;

endIndex = ...
    startIndex + info.originalLength - 1;

y = yPad(startIndex:endIndex);

end