
function result = modified_spectral_subtraction( ...
    fullNoisy, fs, prefixDuration, ...
    winLength, hopSize, nfft, alpha, beta)

% Modified spectral subtraction
% alpha: over-subtraction factor
% beta: minimum spectral gain
%
% G = max(1 - alpha * Nhat / |Y|, beta)
% S_hat = G * Y

%% Validate parameters

if alpha < 1
    error("Alpha must be greater than or equal to 1.");
end

if beta < 0 || beta >= 1
    error("Beta must be between 0 and 1.");
end

fullNoisy = fullNoisy(:);

%% STFT analysis

[Y, stftInfo] = stft_analysis_custom( ...
    fullNoisy, fs, winLength, hopSize, nfft);

magnitudeY = abs(Y);

%% Estimate noise magnitude from the initial prefix

prefixSamples = round(prefixDuration * fs);

if prefixSamples > length(fullNoisy) || ...
        prefixSamples < winLength
    error("Invalid noise-only prefix duration.");
end

noisePrefix = fullNoisy(1:prefixSamples);

window = hann(winLength, 'periodic');

numNoiseFrames = floor( ...
    (prefixSamples - winLength) / hopSize) + 1;

noiseMagnitudeFrames = zeros(nfft, numNoiseFrames);

for m = 1:numNoiseFrames

    idx1 = (m-1)*hopSize + 1;
    idx2 = idx1 + winLength - 1;

    frame = noisePrefix(idx1:idx2);
    frame = frame .* window;

    noiseMagnitudeFrames(:,m) = ...
        abs(fft(frame, nfft));
end

noiseMagnitude = mean(noiseMagnitudeFrames, 2);

%% Modified spectral subtraction

noiseRatio = noiseMagnitude ./ max(magnitudeY, eps);

gain = max(1 - alpha * noiseRatio, beta);

gain = min(gain, 1);

%% Apply spectral gain

S_hat = Y .* gain;

%% ISTFT reconstruction

enhancedFull = stft_synthesis_custom( ...
    S_hat, stftInfo);

%% Store results

result.enhancedFull = enhancedFull;
result.gain = gain;
result.noiseMagnitude = noiseMagnitude;
result.inputSTFT = Y;
result.outputSTFT = S_hat;
result.stftInfo = stftInfo;
result.alpha = alpha;
result.beta = beta;

end
