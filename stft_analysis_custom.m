function [X, info] = stft_analysis_custom(x, fs, winLength, hopSize, nfft)

% Ensure column vector
x = x(:);

% Analysis window
window = hann(winLength, 'periodic');

% Pad both ends so Hann window does not lose edge samples
padLength = winLength;

xPad = [
    zeros(padLength,1);
    x;
    zeros(padLength,1)
    ];

% Number of frames
numFrames = ceil( ...
    (length(xPad) - winLength) / hopSize) + 1;

% Required padded length
requiredLength = ...
    (numFrames - 1)*hopSize + winLength;

% Additional zero padding if required
if length(xPad) < requiredLength
    xPad(end+1:requiredLength) = 0;
end

% STFT matrix
X = zeros(nfft, numFrames);

for m = 1:numFrames

    idx1 = (m-1)*hopSize + 1;
    idx2 = idx1 + winLength - 1;

    frame = xPad(idx1:idx2);

    frame = frame .* window;

    X(:,m) = fft(frame, nfft);
end

% Save information required for reconstruction
info.fs = fs;
info.winLength = winLength;
info.hopSize = hopSize;
info.nfft = nfft;
info.window = window;

info.padLength = padLength;
info.originalLength = length(x);
info.paddedLength = requiredLength;

end